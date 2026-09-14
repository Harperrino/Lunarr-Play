import 'dart:io';
import 'dart:typed_data';

import 'package:m3uxtream_player/core/security/secure_secret_store.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Stores one DPAPI-encrypted, atomically replaced application secret map.
class PersistentSecureSecretStore implements SecureSecretStore {
  PersistentSecureSecretStore(
    this._cipher, {
    Future<Directory> Function()? directoryProvider,
    this.fileName = 'application_secrets.dpapi',
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final SecureSecretCipher _cipher;
  final Future<Directory> Function() _directoryProvider;
  final String fileName;
  final SecureSecretPayloadCodec _codec = const SecureSecretPayloadCodec();
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<String?> read(String key) => _serialize(() async {
    final values = await _readAllUnlocked();
    return values[key];
  });

  @override
  Future<void> write(String key, String value) => _serialize(() async {
    final values = await _readAllUnlocked();
    values[key] = value;
    await _writeAllUnlocked(values);
  });

  @override
  Future<void> delete(String key) => _serialize(() async {
    final values = await _readAllUnlocked();
    if (values.remove(key) == null) return;
    await _writeAllUnlocked(values);
  });

  Future<Map<String, String>> _readAllUnlocked() async {
    final file = await _file();
    if (!await file.exists()) return <String, String>{};
    final encrypted = await file.readAsBytes();
    final clear = await _cipher.unprotect(Uint8List.fromList(encrypted));
    return _codec.decode(clear);
  }

  Future<void> _writeAllUnlocked(Map<String, String> values) async {
    final file = await _file();
    if (values.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }

    final encrypted = await _cipher.protect(_codec.encode(values));
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

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completion = _operationTail.then((_) => operation());
    _operationTail = completion.then<void>((_) {}, onError: (_, _) {});
    return completion;
  }

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, fileName));
  }
}
