import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Secure boundary for Jellyfin access tokens.
///
/// The persistent implementation stores only a DPAPI-encrypted blob. The
/// normal Drift app-state store must never receive connection metadata or a
/// token.
abstract class JellyfinCredentialsStore {
  /// Legacy single-session read used by existing test doubles.
  Future<JellyfinConnection?> read() => readActive();

  Future<JellyfinConnection?> readActive() => read();

  Future<List<JellyfinConnection>> readAll() async {
    final connection = await readActive();
    return connection == null ? const [] : [connection];
  }

  Future<void> write(JellyfinConnection connection);

  Future<void> select(String credentialId) async {}

  Future<void> remove(String credentialId) => clear();

  Future<void> clear();
}

/// Memory-only store: used by tests and unsupported host platforms.
class InMemoryJellyfinCredentialsStore extends JellyfinCredentialsStore {
  final Map<String, JellyfinConnection> _connections = {};
  String? _activeId;

  @override
  Future<JellyfinConnection?> readActive() async =>
      _activeId == null ? null : _connections[_activeId];

  @override
  Future<List<JellyfinConnection>> readAll() async =>
      _connections.values.toList(growable: false);

  @override
  Future<void> write(JellyfinConnection connection) async {
    _connections[connection.credentialId] = connection;
    _activeId = connection.credentialId;
  }

  @override
  Future<void> select(String credentialId) async {
    if (_connections.containsKey(credentialId)) _activeId = credentialId;
  }

  @override
  Future<void> remove(String credentialId) async {
    _connections.remove(credentialId);
    if (_activeId == credentialId) {
      _activeId = _connections.isEmpty ? null : _connections.keys.first;
    }
  }

  @override
  Future<void> clear() async {
    _connections.clear();
    _activeId = null;
  }
}

/// Encrypts bytes with the host platform's user-bound secure storage.
abstract interface class JellyfinCredentialCipher {
  Future<Uint8List> protect(Uint8List plainText);

  Future<Uint8List> unprotect(Uint8List protectedBytes);
}

/// Windows runner implementation backed by DPAPI (CryptProtectData).
class WindowsDpapiCredentialCipher implements JellyfinCredentialCipher {
  const WindowsDpapiCredentialCipher();

  static const _channel = MethodChannel('lunarr/secure_credentials');

  @override
  Future<Uint8List> protect(Uint8List plainText) async {
    final protectedBytes = await _channel.invokeMethod<Uint8List>(
      'protect',
      plainText,
    );
    if (protectedBytes == null) {
      throw const JellyfinCredentialsException('DPAPI returned no ciphertext.');
    }
    return protectedBytes;
  }

  @override
  Future<Uint8List> unprotect(Uint8List protectedBytes) async {
    final plainText = await _channel.invokeMethod<Uint8List>(
      'unprotect',
      protectedBytes,
    );
    if (plainText == null) {
      throw const JellyfinCredentialsException('DPAPI returned no plaintext.');
    }
    return plainText;
  }
}

class JellyfinCredentialsException implements Exception {
  const JellyfinCredentialsException(this.message);

  final String message;

  @override
  String toString() => 'JellyfinCredentialsException: $message';
}

/// Persists all saved accounts as one encrypted payload in app support.
class PersistentJellyfinCredentialsStore extends JellyfinCredentialsStore {
  PersistentJellyfinCredentialsStore({
    required this._cipher,
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const _fileName = 'jellyfin_credentials.dpapi';

  final JellyfinCredentialCipher _cipher;
  final Future<Directory> Function() _directoryProvider;

  @override
  Future<JellyfinConnection?> readActive() async {
    final payload = await _readPayload();
    final activeId = payload.activeId;
    if (activeId == null) return null;
    for (final connection in payload.connections) {
      if (connection.credentialId == activeId) return connection;
    }
    return null;
  }

  @override
  Future<List<JellyfinConnection>> readAll() async =>
      (await _readPayload()).connections;

  @override
  Future<void> write(JellyfinConnection connection) async {
    final payload = await _readPayload();
    final byId = {
      for (final item in payload.connections) item.credentialId: item,
    };
    byId[connection.credentialId] = connection;
    await _writePayload(
      _CredentialPayload(
        connections: byId.values.toList(growable: false),
        activeId: connection.credentialId,
      ),
    );
  }

  @override
  Future<void> select(String credentialId) async {
    final payload = await _readPayload();
    if (!payload.connections.any((item) => item.credentialId == credentialId)) {
      return;
    }
    await _writePayload(
      _CredentialPayload(
        connections: payload.connections,
        activeId: credentialId,
      ),
    );
  }

  @override
  Future<void> remove(String credentialId) async {
    final payload = await _readPayload();
    final remaining = payload.connections
        .where((item) => item.credentialId != credentialId)
        .toList(growable: false);
    await _writePayload(
      _CredentialPayload(
        connections: remaining,
        activeId: payload.activeId == credentialId
            ? (remaining.isEmpty ? null : remaining.first.credentialId)
            : payload.activeId,
      ),
    );
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  Future<_CredentialPayload> _readPayload() async {
    final file = await _file();
    if (!await file.exists()) return const _CredentialPayload.empty();
    try {
      final encrypted = await file.readAsBytes();
      final decrypted = await _cipher.unprotect(Uint8List.fromList(encrypted));
      return _CredentialPayload.fromJson(jsonDecode(utf8.decode(decrypted)));
    } catch (_) {
      // A user-bound DPAPI blob can become unreadable after profile restore or
      // corruption. Remove only that encrypted blob so a new login can recover.
      try {
        await clear();
      } catch (_) {}
      return const _CredentialPayload.empty();
    }
  }

  Future<void> _writePayload(_CredentialPayload payload) async {
    if (payload.connections.isEmpty) return clear();
    final encrypted = await _cipher.protect(
      Uint8List.fromList(utf8.encode(jsonEncode(payload.toJson()))),
    );
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(encrypted, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}

class _CredentialPayload {
  const _CredentialPayload({required this.connections, required this.activeId});
  const _CredentialPayload.empty() : connections = const [], activeId = null;

  final List<JellyfinConnection> connections;
  final String? activeId;

  factory _CredentialPayload.fromJson(Object? value) {
    if (value is! Map || value['version'] != _credentialSchemaVersion) {
      throw const FormatException('Unknown Jellyfin credential payload.');
    }
    final rawConnections = value['connections'];
    if (rawConnections is! List) {
      throw const FormatException('Malformed Jellyfin credential payload.');
    }
    return _CredentialPayload(
      connections: rawConnections
          .map(JellyfinConnection.fromJson)
          .whereType<JellyfinConnection>()
          .toList(growable: false),
      activeId: value['activeId']?.toString(),
    );
  }

  Map<String, Object?> toJson() => {
    'version': _credentialSchemaVersion,
    'activeId': activeId,
    'connections': connections.map((item) => item.toJson()).toList(),
  };
}

const _credentialSchemaVersion = 1;
