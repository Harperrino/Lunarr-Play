import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/providers/series_providers.dart';

void main() {
  testWidgets('All catalogue scope survives opening a movie', (tester) async {
    final ref = await _pumpRefProbe(tester);

    ref.read(playlistCatalogScopeProvider.notifier).state =
        const PlaylistCatalogScope.allActive();

    // The VOD grid uses this exact boundary when a movie is opened.
    selectConcretePlaylistContext(ref, 7);

    // The concrete detail/playback context receives the owner playlist...
    expect(ref.read(selectedPlaylistIdProvider), 7);
    // ...while the catalogue scope stays on the synthetic All view.
    expect(
      ref.read(playlistCatalogScopeProvider),
      const PlaylistCatalogScope.allActive(),
    );
    expect(
      ref.read(effectivePlaylistCatalogScopeProvider).isAllActive,
      isTrue,
    );
  });

  testWidgets('All catalogue scope survives opening a series episode', (
    tester,
  ) async {
    final ref = await _pumpRefProbe(tester);

    ref.read(playlistCatalogScopeProvider.notifier).state =
        const PlaylistCatalogScope.allActive();

    selectSeriesEpisodePrep(
      ref,
      seriesChannel: _seriesChannel(id: 11, playlistId: 9),
      episode: const ParsedSeriesEpisode(
        episodeId: 'ep-1',
        title: 'Episode 1',
        streamUrl: 'https://example.invalid/series/ep1',
        season: 1,
        episodeNum: 1,
      ),
    );

    // Detail and playback resolve against the concrete owner playlist.
    expect(ref.read(selectedPlaylistIdProvider), 9);
    expect(ref.read(seriesActivePlaybackProvider)?.playlistId, 9);
    // The catalogue scope itself was never rewritten.
    expect(
      ref.read(playlistCatalogScopeProvider),
      const PlaylistCatalogScope.allActive(),
    );
    expect(
      ref.read(effectivePlaylistCatalogScopeProvider).isAllActive,
      isTrue,
    );
  });

  testWidgets('an explicit single scope is not rewritten either', (
    tester,
  ) async {
    final ref = await _pumpRefProbe(tester);

    ref.read(playlistCatalogScopeProvider.notifier).state =
        const PlaylistCatalogScope.single(3);

    selectConcretePlaylistContext(ref, 3);

    expect(ref.read(selectedPlaylistIdProvider), 3);
    expect(
      ref.read(playlistCatalogScopeProvider),
      const PlaylistCatalogScope.single(3),
    );
  });
}

Future<WidgetRef> _pumpRefProbe(WidgetTester tester) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

Channel _seriesChannel({required int id, required int playlistId}) {
  return Channel(
    providerOrder: 0,
    id: id,
    playlistId: playlistId,
    streamId: 'series-$id',
    name: 'Series $id',
    logo: null,
    groupName: 'Drama',
    tvgId: null,
    streamUrl: 'https://example.invalid/series/$id',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'series',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}
