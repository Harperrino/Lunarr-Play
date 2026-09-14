import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';

const _alice = JellyfinConnection(
  baseUrl: 'https://media.example',
  serverId: 'server-1',
  serverVersion: '10.10.3',
  userId: 'alice-id',
  username: 'alice',
  accessToken: 'alice-secret-token',
  deviceId: 'device-1',
);

const _bob = JellyfinConnection(
  baseUrl: 'https://other.example',
  serverId: 'server-2',
  serverVersion: '10.10.3',
  userId: 'bob-id',
  username: 'bob',
  accessToken: 'bob-secret-token',
  deviceId: 'device-2',
);

class _TestCipher implements JellyfinCredentialCipher {
  const _TestCipher();

  @override
  Future<Uint8List> protect(Uint8List plainText) async => Uint8List.fromList(
    plainText.reversed.map((byte) => byte ^ 0x5a).toList(),
  );

  @override
  Future<Uint8List> unprotect(Uint8List protectedBytes) async =>
      Uint8List.fromList(
        protectedBytes.reversed.map((byte) => byte ^ 0x5a).toList(),
      );
}

class _FaultingCipher implements JellyfinCredentialCipher {
  bool failTransiently = false;
  bool failDpapi = false;

  @override
  Future<Uint8List> protect(Uint8List plainText) =>
      const _TestCipher().protect(plainText);

  @override
  Future<Uint8List> unprotect(Uint8List protectedBytes) async {
    if (failTransiently) {
      failTransiently = false;
      throw MissingPluginException('temporary channel failure');
    }
    if (failDpapi) {
      throw PlatformException(code: 'dpapi_failed');
    }
    return const _TestCipher().unprotect(protectedBytes);
  }
}

void main() {
  test(
    'persists multiple encrypted Jellyfin connections and active selection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lunarr-jellyfin-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = PersistentJellyfinCredentialsStore(
        cipher: const _TestCipher(),
        directoryProvider: () async => directory,
      );

      await store.write(_alice);
      await store.write(_bob);

      final reloaded = PersistentJellyfinCredentialsStore(
        cipher: const _TestCipher(),
        directoryProvider: () async => directory,
      );
      expect(await reloaded.readAll(), hasLength(2));
      expect((await reloaded.readActive())?.credentialId, _bob.credentialId);

      final files = await directory.list().toList();
      expect(files, hasLength(1));
      expect(
        await (files.single as File).readAsString(),
        isNot(contains('bob-secret-token')),
      );

      await reloaded.select(_alice.credentialId);
      expect((await reloaded.readActive())?.credentialId, _alice.credentialId);
      await reloaded.remove(_alice.credentialId);
      expect((await reloaded.readActive())?.credentialId, _bob.credentialId);
    },
  );

  test(
    'serializes concurrent credential mutations without losing accounts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lunarr-jellyfin-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = PersistentJellyfinCredentialsStore(
        cipher: const _TestCipher(),
        directoryProvider: () async => directory,
      );

      await Future.wait([store.write(_alice), store.write(_bob)]);

      expect(
        (await store.readAll()).map((connection) => connection.credentialId),
        containsAll([_alice.credentialId, _bob.credentialId]),
      );
      expect((await store.readActive())?.credentialId, _bob.credentialId);
    },
  );

  test('keeps the primary blob after a transient cipher failure', () async {
    final directory = await Directory.systemTemp.createTemp('lunarr-jellyfin-');
    addTearDown(() => directory.delete(recursive: true));
    final cipher = _FaultingCipher();
    final store = PersistentJellyfinCredentialsStore(
      cipher: cipher,
      directoryProvider: () async => directory,
    );
    await store.write(_alice);
    final original =
        (await directory.list().where((entry) => entry is File).single) as File;

    cipher.failTransiently = true;
    await expectLater(
      store.readActive(),
      throwsA(isA<MissingPluginException>()),
    );

    expect(await original.exists(), isTrue);
    expect((await store.readActive())?.credentialId, _alice.credentialId);
  });

  test('quarantines and later restores an unreadable encrypted blob', () async {
    final directory = await Directory.systemTemp.createTemp('lunarr-jellyfin-');
    addTearDown(() => directory.delete(recursive: true));
    final cipher = _FaultingCipher();
    final store = PersistentJellyfinCredentialsStore(
      cipher: cipher,
      directoryProvider: () async => directory,
    );
    await store.write(_alice);

    cipher.failDpapi = true;
    expect(await store.readActive(), isNull);
    final quarantined = await directory
        .list()
        .where((entry) => entry is File)
        .toList();
    expect(quarantined, hasLength(1));
    expect(quarantined.single.path, contains('.recovery.'));

    cipher.failDpapi = false;
    expect((await store.readActive())?.credentialId, _alice.credentialId);
    final restored = await directory
        .list()
        .where((entry) => entry is File)
        .toList();
    expect(restored, hasLength(1));
    expect(restored.single.path, isNot(contains('.recovery.')));
  });
}
