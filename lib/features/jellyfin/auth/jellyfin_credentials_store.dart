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
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<JellyfinConnection?> readActive() => _serialize(() async {
    final payload = await _readPayloadUnlocked();
    final activeId = payload.activeId;
    if (activeId == null) return null;
    for (final connection in payload.connections) {
      if (connection.credentialId == activeId) return connection;
    }
    return null;
  });

  @override
  Future<List<JellyfinConnection>> readAll() =>
      _serialize(() async => (await _readPayloadUnlocked()).connections);

  @override
  Future<void> write(JellyfinConnection connection) => _serialize(() async {
    final payload = await _readPayloadUnlocked();
    final byId = {
      for (final item in payload.connections) item.credentialId: item,
    };
    byId[connection.credentialId] = connection;
    await _writePayloadUnlocked(
      _CredentialPayload(
        connections: byId.values.toList(growable: false),
        activeId: connection.credentialId,
      ),
    );
  });

  @override
  Future<void> select(String credentialId) => _serialize(() async {
    final payload = await _readPayloadUnlocked();
    if (!payload.connections.any((item) => item.credentialId == credentialId)) {
      return;
    }
    await _writePayloadUnlocked(
      _CredentialPayload(
        connections: payload.connections,
        activeId: credentialId,
      ),
    );
  });

  @override
  Future<void> remove(String credentialId) => _serialize(() async {
    final payload = await _readPayloadUnlocked();
    final remaining = payload.connections
        .where((item) => item.credentialId != credentialId)
        .toList(growable: false);
    await _writePayloadUnlocked(
      _CredentialPayload(
        connections: remaining,
        activeId: payload.activeId == credentialId
            ? (remaining.isEmpty ? null : remaining.first.credentialId)
            : payload.activeId,
      ),
    );
  });

  @override
  Future<void> clear() => _serialize(_clearUnlocked);

  Future<void> _clearUnlocked() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    if (!await file.parent.exists()) return;
    await for (final entity in file.parent.list()) {
      if (entity is File && _isRecoveryFile(file, entity)) {
        await entity.delete();
      }
    }
  }

  Future<_CredentialPayload> _readPayloadUnlocked() async {
    final file = await _file();
    if (!await file.exists()) {
      final recovered = await _restoreReadableRecovery(file);
      if (recovered != null) return recovered;
      return const _CredentialPayload.empty();
    }
    try {
      return await _decodePayload(file);
    } catch (error) {
      if (!_isUnreadablePayload(error)) rethrow;
      await _quarantine(file);
      return const _CredentialPayload.empty();
    }
  }

  Future<void> _writePayloadUnlocked(_CredentialPayload payload) async {
    if (payload.connections.isEmpty) {
      final file = await _file();
      if (await file.exists()) await file.delete();
      return;
    }
    final encrypted = await _cipher.protect(
      Uint8List.fromList(utf8.encode(jsonEncode(payload.toJson()))),
    );
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.backup');
    await temporary.writeAsBytes(encrypted, flush: true);
    var movedExisting = false;
    try {
      if (await backup.exists()) await backup.delete();
      if (await file.exists()) {
        await file.rename(backup.path);
        movedExisting = true;
      }
      await temporary.rename(file.path);
      if (movedExisting && await backup.exists()) await backup.delete();
    } catch (_) {
      if (movedExisting && !await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<_CredentialPayload> _decodePayload(File file) async {
    final encrypted = await file.readAsBytes();
    final decrypted = await _cipher.unprotect(Uint8List.fromList(encrypted));
    return _CredentialPayload.fromJson(jsonDecode(utf8.decode(decrypted)));
  }

  Future<_CredentialPayload?> _restoreReadableRecovery(File primary) async {
    if (!await primary.parent.exists()) return null;
    final candidates = <File>[];
    await for (final entity in primary.parent.list()) {
      if (entity is File && _isRecoveryFile(primary, entity)) {
        candidates.add(entity);
      }
    }
    candidates.sort((left, right) => right.path.compareTo(left.path));
    for (final candidate in candidates) {
      try {
        final payload = await _decodePayload(candidate);
        await candidate.rename(primary.path);
        return payload;
      } catch (error) {
        if (!_isUnreadablePayload(error)) rethrow;
      }
    }
    return null;
  }

  Future<void> _quarantine(File file) async {
    var suffix = DateTime.now().microsecondsSinceEpoch;
    File recovery;
    do {
      recovery = File('${file.path}.recovery.$suffix');
      suffix++;
    } while (await recovery.exists());
    await file.rename(recovery.path);
  }

  bool _isRecoveryFile(File primary, File candidate) =>
      candidate.path.startsWith('${primary.path}.recovery.');

  bool _isUnreadablePayload(Object error) =>
      error is FormatException ||
      error is JellyfinCredentialsException ||
      error is PlatformException && error.code == 'dpapi_failed';

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completion = _operationTail.then((_) => operation());
    _operationTail = completion.then<void>((_) {}, onError: (_, _) {});
    return completion;
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
