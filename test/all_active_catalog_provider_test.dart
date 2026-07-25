import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_sort_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

const _channelsPerPlaylist = int.fromEnvironment(
  'ALL_ACTIVE_CHANNELS_PER_PLAYLIST',
  defaultValue: 5,
);

void main() {
  test(
    'single to all-active emits the combined catalogue',
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);

      final playlistIds = <int>[];
      for (var playlistIndex = 0; playlistIndex < 4; playlistIndex++) {
        final playlistId = await database
            .into(database.playlists)
            .insert(
              PlaylistsCompanion.insert(
                name: 'Playlist $playlistIndex',
                type: 'm3u',
                urlOrHost: 'https://example.invalid/$playlistIndex.m3u',
              ),
            );
        playlistIds.add(playlistId);
        for (var offset = 0; offset < _channelsPerPlaylist; offset += 1000) {
          final end = (offset + 1000).clamp(0, _channelsPerPlaylist);
          await database.batch((batch) {
            batch.insertAll(database.channels, [
              for (
                var channelIndex = offset;
                channelIndex < end;
                channelIndex++
              )
                ChannelsCompanion.insert(
                  playlistId: playlistId,
                  name: 'P$playlistIndex Channel $channelIndex',
                  streamUrl:
                      'https://example.invalid/$playlistIndex/$channelIndex',
                  channelType: 'live',
                  providerOrder: Value(channelIndex + 1),
                ),
            ]);
          });
        }
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      await container.read(playlistsStreamProvider.future);
      await container.read(inactivePlaylistIdsProvider.future);
      container.read(selectedPlaylistIdProvider.notifier).state =
          playlistIds.first;
      container.read(playlistCatalogScopeProvider.notifier).state =
          PlaylistCatalogScope.single(playlistIds.first);

      final liveSubscription = container.listen(
        liveChannelsStreamProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final categorySubscription = container.listen(
        liveCategoryEntriesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final sortedSubscription = container.listen(
        sortedFilteredChannelsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(liveSubscription.close);
      addTearDown(categorySubscription.close);
      addTearDown(sortedSubscription.close);

      final single = await _waitForChannels(
        container,
        expectedCount: _channelsPerPlaylist,
      );
      expect(single, hasLength(_channelsPerPlaylist));

      container.read(playlistCatalogScopeProvider.notifier).state =
          const PlaylistCatalogScope.allActive();
      final stopwatch = Stopwatch()..start();
      final all = await _waitForChannels(
        container,
        expectedCount: _channelsPerPlaylist * playlistIds.length,
      );
      stopwatch.stop();

      expect(all, hasLength(_channelsPerPlaylist * playlistIds.length));
      expect(all.map((channel) => channel.playlistId).toList(), <int>[
        for (final playlistId in playlistIds)
          for (
            var channelIndex = 0;
            channelIndex < _channelsPerPlaylist;
            channelIndex++
          )
            playlistId,
      ]);

      // The combined result must prime every concrete scope. Switching
      // through the top-bar playlists now receives the first rows from the
      // same in-memory snapshot instead of opening one cold query per scope.
      final switchStopwatch = Stopwatch()..start();
      for (final playlistId in playlistIds) {
        container.read(playlistCatalogScopeProvider.notifier).state =
            PlaylistCatalogScope.single(playlistId);
        final rawSingle = await _waitForRawChannels(
          container,
          expectedCount: _channelsPerPlaylist,
          expectedPlaylistId: playlistId,
        );
        expect(rawSingle, hasLength(_channelsPerPlaylist));
        expect(
          rawSingle.every((channel) => channel.playlistId == playlistId),
          isTrue,
        );
        final single = await _waitForChannels(
          container,
          expectedCount: _channelsPerPlaylist,
          expectedPlaylistId: playlistId,
        );
        expect(single, hasLength(_channelsPerPlaylist));
        expect(
          single.every((channel) => channel.playlistId == playlistId),
          isTrue,
        );
      }
      switchStopwatch.stop();
      if (_channelsPerPlaylist > 5) {
        // ignore: avoid_print
        print(
          'all-active ${all.length} channels emitted in '
          '${stopwatch.elapsedMilliseconds} ms; '
          '${playlistIds.length} warm switches in '
          '${switchStopwatch.elapsedMilliseconds} ms',
        );
      }
    },
  );
}

Future<List<Channel>> _waitForChannels(
  ProviderContainer container, {
  required int expectedCount,
  int? expectedPlaylistId,
}) async {
  for (var attempt = 0; attempt < 6000; attempt++) {
    final channels =
        container.read(sortedFilteredChannelsProvider).valueOrNull ??
        const <Channel>[];
    if (channels.length == expectedCount &&
        (expectedPlaylistId == null ||
            channels.every(
              (channel) => channel.playlistId == expectedPlaylistId,
            ))) {
      return channels;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(sortedFilteredChannelsProvider).valueOrNull ??
      const <Channel>[];
}

Future<List<Channel>> _waitForRawChannels(
  ProviderContainer container, {
  required int expectedCount,
  required int expectedPlaylistId,
}) async {
  for (var attempt = 0; attempt < 6000; attempt++) {
    final channels =
        container.read(liveChannelsStreamProvider).valueOrNull ??
        const <Channel>[];
    if (channels.length == expectedCount &&
        channels.every((channel) => channel.playlistId == expectedPlaylistId)) {
      return channels;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(liveChannelsStreamProvider).valueOrNull ??
      const <Channel>[];
}
