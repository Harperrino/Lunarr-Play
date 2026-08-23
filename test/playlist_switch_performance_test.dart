import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';

/// Opt-in 50k-channel playlist-switch probe. The release/profile targets are
/// p95 <= 150 ms warm and p95 <= 500 ms cold; this debug-JIT run reports
/// indicative numbers and guards only against gross regressions.
const _runPlaylistSwitchPerformance = bool.fromEnvironment(
  'PLAYLIST_SWITCH_PERF',
);

void main() {
  test(
    '50k-channel playlist switches stay bounded (cold and warm)',
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !_runPlaylistSwitchPerformance,
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PlaylistRepository(database);

      final playlistIds = <int>[];
      for (var index = 0; index < 2; index++) {
        playlistIds.add(
          await database
              .into(database.playlists)
              .insert(
                PlaylistsCompanion.insert(
                  name: 'Perf $index',
                  type: 'm3u',
                  urlOrHost: 'https://example.invalid/perf-$index',
                ),
              ),
        );
      }

      // Search triggers are irrelevant for the catalogue switch probe and
      // would dominate the fixture setup time.
      for (final trigger in const [
        'search_documents_ai',
        'search_documents_ad',
        'search_documents_au',
        'search_documents_channel_ad',
      ]) {
        await database.customStatement('DROP TRIGGER IF EXISTS $trigger');
      }

      const channelsPerPlaylist = 25000;
      for (final playlistId in playlistIds) {
        for (var offset = 0; offset < channelsPerPlaylist; offset += 1000) {
          final end = (offset + 1000).clamp(0, channelsPerPlaylist);
          await database.batch((batch) {
            for (var index = offset; index < end; index++) {
              batch.insertAll(database.channels, [
                ChannelsCompanion.insert(
                  playlistId: playlistId,
                  name: 'Channel $index',
                  streamUrl: 'https://example.invalid/$playlistId/$index',
                  channelType: 'live',
                  providerOrder: Value(index),
                ),
              ]);
            }
          });
        }
      }

      // Cold switches: every call opens a fresh catalogue stream against the
      // indexed 50k-row table.
      final coldDurations = <Duration>[];
      for (var switchIndex = 0; switchIndex < 20; switchIndex++) {
        final playlistId = playlistIds[switchIndex % playlistIds.length];
        final stopwatch = Stopwatch()..start();
        final channels = await repository.watchChannelsByPlaylistIdsAndType([
          playlistId,
        ], 'live').first;
        stopwatch.stop();
        expect(channels, hasLength(channelsPerPlaylist));
        coldDurations.add(stopwatch.elapsed);
      }

      // Warm switches: the warm cache serves the first catalogue state
      // synchronously, exactly like the UI re-entering a scope.
      final cache = PlaylistCatalogWarmCache();
      final warmDurations = <Duration>[];
      for (var switchIndex = 0; switchIndex < 20; switchIndex++) {
        final playlistId = playlistIds[switchIndex % playlistIds.length];
        final query = PlaylistCatalogQuery(
          scope: PlaylistCatalogScope.single(playlistId),
          mediaType: PlaylistCatalogMediaType.live,
        );
        // Prime the entry once, then measure the re-entry hit.
        await watchPlaylistCatalog(
          repository: repository,
          cache: cache,
          query: query,
          playlistIds: [playlistId],
        ).first;
        final stopwatch = Stopwatch()..start();
        final first = await watchPlaylistCatalog(
          repository: repository,
          cache: cache,
          query: query,
          playlistIds: [playlistId],
        ).first;
        stopwatch.stop();
        expect(first, hasLength(channelsPerPlaylist));
        warmDurations.add(stopwatch.elapsed);
      }

      Duration p95(List<Duration> values) {
        final sorted = [...values]..sort();
        return sorted[(0.95 * (sorted.length - 1)).round()];
      }

      // ignore: avoid_print
      print(
        'playlist switch 50k: cold p95=${p95(coldDurations).inMicroseconds / 1000}ms '
        'max=${coldDurations.reduce((a, b) => a > b ? a : b).inMilliseconds}ms; '
        'warm p95=${p95(warmDurations).inMicroseconds / 1000}ms '
        'max=${warmDurations.reduce((a, b) => a > b ? a : b).inMilliseconds}ms',
      );

      // Generous debug-JIT guards only; the release/profile targets
      // (150/500 ms p95) are asserted by the manual Windows profiling lane.
      expect(p95(coldDurations), lessThan(const Duration(seconds: 2)));
      expect(p95(warmDurations), lessThan(const Duration(seconds: 1)));
    },
  );
}
