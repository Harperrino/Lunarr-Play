import 'dart:convert';

import 'package:flutter/services.dart';

/// Minimal encrypted key/value boundary for application secrets.
///
/// Callers own key names and must never place secret values in Drift, logs, or
/// diagnostics. The Windows implementation uses the existing DPAPI channel.
abstract interface class SecureSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class InMemorySecureSecretStore implements SecureSecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

abstract interface class SecureSecretCipher {
  Future<Uint8List> protect(Uint8List plainText);

  Future<Uint8List> unprotect(Uint8List protectedBytes);
}

class WindowsDpapiSecretCipher implements SecureSecretCipher {
  const WindowsDpapiSecretCipher();

  static const _channel = MethodChannel('lunarr/secure_credentials');

  @override
  Future<Uint8List> protect(Uint8List plainText) async {
    final value = await _channel.invokeMethod<Uint8List>('protect', plainText);
    if (value == null) {
      throw const SecureSecretStoreException(
        'Secure storage returned no data.',
      );
    }
    return value;
  }

  @override
  Future<Uint8List> unprotect(Uint8List protectedBytes) async {
    final value = await _channel.invokeMethod<Uint8List>(
      'unprotect',
      protectedBytes,
    );
    if (value == null) {
      throw const SecureSecretStoreException(
        'Secure storage returned no data.',
      );
    }
    return value;
  }
}

class SecureSecretStoreException implements Exception {
  const SecureSecretStoreException(this.message);

  final String message;

  @override
  String toString() => 'SecureSecretStoreException: $message';
}

/// Codec shared by persistent secret stores. It deliberately exposes only an
/// encrypted byte payload to platform/file adapters.
class SecureSecretPayloadCodec {
  const SecureSecretPayloadCodec();

  Uint8List encode(Map<String, String> values) => Uint8List.fromList(
    utf8.encode(jsonEncode(<String, Object?>{'version': 1, 'values': values})),
  );

  Map<String, String> decode(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded['version'] != 1) {
      throw const FormatException('Unknown secure secret payload.');
    }
    final rawValues = decoded['values'];
    if (rawValues is! Map) {
      throw const FormatException('Malformed secure secret payload.');
    }
    return <String, String>{
      for (final entry in rawValues.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }
}
