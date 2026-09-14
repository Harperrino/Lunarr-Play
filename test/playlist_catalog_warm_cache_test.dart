import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';

void main() {
  PlaylistCatalogQuery live(PlaylistCatalogScope scope) => PlaylistCatalogQuery(
    scope: scope,
    mediaType: PlaylistCatalogMediaType.live,
  );

  test('invalidateForPlaylist drops only scopes covering that playlist', () {
    final cache = PlaylistCatalogWarmCache();
    final single1 = live(const PlaylistCatalogScope.single(1));
    final single1Vod = PlaylistCatalogQuery(
      scope: const PlaylistCatalogScope.single(1),
      mediaType: PlaylistCatalogMediaType.vod,
    );
    final single2 = live(const PlaylistCatalogScope.single(2));
    final all = live(const PlaylistCatalogScope.allActive());

    cache.write(single1, const <Channel>[]);
    cache.write(single1Vod, const <Channel>[]);
    cache.write(single2, const <Channel>[]);
    cache.write(all, const <Channel>[]);

    cache.invalidateForPlaylist(1);

    expect(cache.read(single1), isNull);
    expect(cache.read(single1Vod), isNull);
    expect(cache.read(all), isNull);
    // Unrelated playlists keep their warm entries.
    expect(cache.read(single2), isNotNull);
  });

  test('the cache stays bounded and reads refresh recency', () {
    final cache = PlaylistCatalogWarmCache();
    final queries = [
      for (var id = 1; id <= PlaylistCatalogWarmCache.maxEntries + 1; id++)
        live(PlaylistCatalogScope.single(id)),
    ];
    for (final query in queries) {
      cache.write(query, const <Channel>[]);
    }

    // One write beyond the bound evicts the oldest entry.
    expect(cache.read(queries.first), isNull);
    expect(cache.read(queries.last), isNotNull);

    // Reading promotes an entry, so a new write evicts the next-oldest.
    expect(cache.read(queries[1]), isNotNull);
    cache.write(
      live(
        PlaylistCatalogScope.single(PlaylistCatalogWarmCache.maxEntries + 2),
      ),
      const <Channel>[],
    );
    expect(cache.read(queries[1]), isNotNull);
    expect(cache.read(queries[2]), isNull);
  });

  test('All-active writes prewarm every covered concrete playlist', () {
    final cache = PlaylistCatalogWarmCache();
    final all = live(const PlaylistCatalogScope.allActive());
    final channels = [
      _channel(id: 10, playlistId: 1),
      _channel(id: 11, playlistId: 1),
      _channel(id: 20, playlistId: 2),
    ];

    cache.write(all, channels, coveredPlaylistIds: const [1, 2, 3]);

    expect(
      cache
          .read(live(const PlaylistCatalogScope.single(1)))!
          .map((channel) => channel.id),
      [10, 11],
    );
    expect(
      cache
          .read(live(const PlaylistCatalogScope.single(2)))!
          .map((channel) => channel.id),
      [20],
    );
    // Empty active playlists are warm too and must not flash a loader.
    expect(cache.read(live(const PlaylistCatalogScope.single(3))), isEmpty);
    expect(cache.read(all), hasLength(3));
  });

  test('overlapping single and All scopes keep independent generations', () {
    final cache = PlaylistCatalogWarmCache();
    final single = live(const PlaylistCatalogScope.single(1));
    final all = live(const PlaylistCatalogScope.allActive());

    final singleGeneration = cache.nextGeneration(single);
    final allGeneration = cache.nextGeneration(all);

    expect(cache.isCurrent(single, singleGeneration), isTrue);
    expect(cache.isCurrent(all, allGeneration), isTrue);

    // Rebuilding one scope invalidates only that exact query.
    cache.nextGeneration(single);
    expect(cache.isCurrent(single, singleGeneration), isFalse);
    expect(cache.isCurrent(all, allGeneration), isTrue);
  });
}

Channel _channel({required int id, required int playlistId}) {
  return Channel(
    id: id,
    playlistId: playlistId,
    streamId: '$id',
    name: 'Channel $id',
    logo: null,
    groupName: 'Group',
    tvgId: null,
    streamUrl: 'https://example.invalid/$id',
    providerOrder: id,
    channelNumber: null,
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}
