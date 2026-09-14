import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/cache/bounded_async_cache.dart';
import 'package:m3uxtream_player/core/cache/bounded_value_cache.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_request_cache.dart';

void main() {
  test(
    'async cache deduplicates, expires and evicts least recently used',
    () async {
      var now = DateTime(2026);
      var loads = 0;
      final cache = BoundedAsyncCache<String, int>(
        maxEntries: 2,
        ttl: const Duration(minutes: 5),
        now: () => now,
      );

      Future<int> load(int value) async {
        loads++;
        return value;
      }

      expect(await cache.getOrLoad('a', () => load(1)), 1);
      expect(await cache.getOrLoad('a', () => load(9)), 1);
      expect(loads, 1);
      await cache.getOrLoad('b', () => load(2));
      await cache.getOrLoad('a', () => load(3));
      await cache.getOrLoad('c', () => load(3));
      expect(cache.length, 2);
      await cache.getOrLoad('b', () => load(4));
      expect(loads, 4);

      now = now.add(const Duration(minutes: 6));
      expect(await cache.getOrLoad('a', () => load(5)), 5);
      expect(loads, 5);
    },
  );

  test('async cache shares pending loads and removes failures', () async {
    final cache = BoundedAsyncCache<String, int>(
      maxEntries: 2,
      ttl: const Duration(minutes: 1),
    );
    final completer = Completer<int>();
    var loads = 0;
    final first = cache.getOrLoad('pending', () {
      loads++;
      return completer.future;
    });
    final second = cache.getOrLoad('pending', () async => 2);
    expect(identical(first, second), isTrue);
    completer.complete(1);
    expect(await second, 1);
    expect(loads, 1);

    await expectLater(
      cache.getOrLoad('failure', () async => throw StateError('failed')),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
    expect(await cache.getOrLoad('failure', () async => 7), 7);
  });

  test('value cache is a bounded LRU', () {
    final cache = BoundedValueCache<String, Object>(maxEntries: 2);
    final a = Object();
    expect(cache.getOrCompute('a', () => a), same(a));
    expect(cache.getOrCompute('a', Object.new), same(a));
    cache.getOrCompute('b', Object.new);
    cache.getOrCompute('c', Object.new);
    expect(cache.length, 2);
    expect(cache.getOrCompute('a', Object.new), isNot(same(a)));
  });

  test('Jellyfin cache keys isolate accounts and redact diagnostics', () async {
    final cache = JellyfinRequestCache<int>(
      maxEntries: 8,
      ttl: const Duration(minutes: 5),
    );
    const alice = JellyfinResourceCacheKey(
      credentialId: 'server:alice',
      resourceId: 'movie-1',
    );
    const bob = JellyfinResourceCacheKey(
      credentialId: 'server:bob',
      resourceId: 'movie-1',
    );

    expect(await cache.getOrLoad(alice, () async => 1), 1);
    expect(await cache.getOrLoad(bob, () async => 2), 2);
    expect(cache.length, 2);
    expect(alice.toString(), isNot(contains('alice')));
    expect(alice.toString(), isNot(contains('movie-1')));

    cache.invalidateCredential('server:alice');
    expect(cache.length, 1);
    expect(await cache.getOrLoad(bob, () async => 9), 2);
  });

  test(
    'Jellyfin detail working set stays bounded after one hundred reads',
    () async {
      final cache = JellyfinRequestCache<int>(
        maxEntries: 32,
        ttl: const Duration(minutes: 5),
      );

      for (var index = 0; index < 100; index++) {
        final key = JellyfinResourceCacheKey(
          credentialId: 'account-a',
          resourceId: 'item-$index',
        );
        expect(await cache.getOrLoad(key, () async => index), index);
      }

      expect(cache.length, 32);
      cache.invalidateCredential('account-a');
      expect(cache.length, 0);
    },
  );

  test(
    'Jellyfin mutations clear account lists and only the changed detail',
    () async {
      final caches = JellyfinLibraryRequestCaches();
      const changed = JellyfinResourceCacheKey(
        credentialId: 'account-a',
        resourceId: 'episode-1',
      );
      const unchanged = JellyfinResourceCacheKey(
        credentialId: 'account-a',
        resourceId: 'episode-2',
      );
      const otherAccount = JellyfinResourceCacheKey(
        credentialId: 'account-b',
        resourceId: 'episode-1',
      );
      const episode = JellyfinItem(
        id: 'episode-1',
        name: 'One',
        type: 'Episode',
      );

      await caches.itemDetails.getOrLoad(changed, () async => episode);
      await caches.itemDetails.getOrLoad(unchanged, () async => episode);
      await caches.itemDetails.getOrLoad(otherAccount, () async => episode);
      await caches.libraryItems.getOrLoad(changed, () async => const [episode]);
      await caches.libraryItems.getOrLoad(
        otherAccount,
        () async => const [episode],
      );
      await caches.seriesEpisodes.getOrLoad(
        changed,
        () async => const [episode],
      );
      await caches.seriesEpisodes.getOrLoad(
        otherAccount,
        () async => const [episode],
      );

      caches.invalidateItemMutation(
        credentialId: 'account-a',
        itemId: 'episode-1',
      );

      expect(caches.itemDetails.length, 2);
      expect(caches.libraryItems.length, 1);
      expect(caches.seriesEpisodes.length, 1);
      expect(
        await caches.itemDetails.getOrLoad(unchanged, () async => episode),
        same(episode),
      );
      expect(
        await caches.itemDetails.getOrLoad(otherAccount, () async => episode),
        same(episode),
      );
    },
  );
}
