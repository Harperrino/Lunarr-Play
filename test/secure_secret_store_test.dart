import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/security/persistent_secure_secret_store.dart';
import 'package:m3uxtream_player/core/security/secure_secret_store.dart';

class _TestCipher implements SecureSecretCipher {
  bool failNextProtect = false;

  @override
  Future<Uint8List> protect(Uint8List plainText) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (failNextProtect) {
      failNextProtect = false;
      throw const SecureSecretStoreException('fixture failure');
    }
    return _xor(plainText);
  }

  @override
  Future<Uint8List> unprotect(Uint8List protectedBytes) async =>
      _xor(protectedBytes);

  Uint8List _xor(Uint8List bytes) => Uint8List.fromList(
    bytes.map((value) => value ^ 0xA5).toList(growable: false),
  );
}

void main() {
  late Directory directory;
  late _TestCipher cipher;
  late PersistentSecureSecretStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lunarr-secret-test-');
    cipher = _TestCipher();
    store = PersistentSecureSecretStore(
      cipher,
      directoryProvider: () async => directory,
      fileName: 'fixture.dpapi',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('serializes parallel writes without losing either secret', () async {
    await Future.wait<void>(<Future<void>>[
      store.write('tmdb', 'fixture-tmdb-token'),
      store.write('seerr', 'fixture-seerr-key'),
    ]);

    expect(await store.read('tmdb'), 'fixture-tmdb-token');
    expect(await store.read('seerr'), 'fixture-seerr-key');
    final raw = String.fromCharCodes(
      await File('${directory.path}/fixture.dpapi').readAsBytes(),
    );
    expect(raw, isNot(contains('fixture-tmdb-token')));
    expect(raw, isNot(contains('fixture-seerr-key')));
  });

  test(
    'failed encryption preserves the previous store and queue recovers',
    () async {
      await store.write('tmdb', 'first-value');
      cipher.failNextProtect = true;

      await expectLater(
        store.write('tmdb', 'must-not-replace'),
        throwsA(isA<SecureSecretStoreException>()),
      );
      expect(await store.read('tmdb'), 'first-value');

      await store.write('seerr', 'second-value');
      expect(await store.read('tmdb'), 'first-value');
      expect(await store.read('seerr'), 'second-value');
    },
  );

  test('removing one key leaves the other encrypted value intact', () async {
    await store.write('tmdb', 'one');
    await store.write('seerr', 'two');

    await store.delete('tmdb');

    expect(await store.read('tmdb'), isNull);
    expect(await store.read('seerr'), 'two');
  });

  test('codec rejects unknown versions and malformed values', () {
    const codec = SecureSecretPayloadCodec();
    expect(
      () => codec.decode(Uint8List.fromList('{"version":2}'.codeUnits)),
      throwsFormatException,
    );
    expect(
      () => codec.decode(
        Uint8List.fromList('{"version":1,"values":[]}'.codeUnits),
      ),
      throwsFormatException,
    );
  });
}
