import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/vod_providers.dart';

const _vodA = Channel(
  id: 101,
  playlistId: 1,
  streamId: 'vod-a',
  name: 'Playlist A movie',
  groupName: 'Action',
  streamUrl: 'https://example.invalid/a.mp4',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'vod',
);

const _seriesA = Channel(
  id: 201,
  playlistId: 1,
  streamId: 'series-a',
  name: 'Playlist A series',
  groupName: 'Drama',
  streamUrl: 'https://example.invalid/a-series',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'series',
);

const _episodeA = ParsedSeriesEpisode(
  episodeId: 'episode-a',
  title: 'Episode A',
  streamUrl: 'https://example.invalid/a-series/episode-a.mp4',
  season: 1,
  episodeNum: 1,
);

void main() {
  test('playlist A to B clears all catalogue-owned selection state', () {
    final container = ProviderContainer(
      overrides: [selectedPlaylistIdProvider.overrideWith((ref) => 1)],
    );
    addTearDown(container.dispose);

    container.read(selectedVodGroupFilterProvider.notifier).state = 'Action';
    container.read(selectedSeriesGroupFilterProvider.notifier).state = 'Drama';
    container.read(selectedSeriesChannelProvider.notifier).state = _seriesA;

    final prepController = container.read(
      playbackPrepControllerProvider.notifier,
    );
    prepController.selectTarget(
      PlaybackPrepTarget(
        playbackChannel: _vodA,
        streamUrl: _vodA.streamUrl,
        posterUrl: _vodA.logo,
        subtitle: _vodA.groupName,
      ),
    );
    prepController.state = const PlaybackPrepState(
      phase: PlaybackPrepPhase.ready,
      errorMessage: 'stale state from playlist A',
    );
    container
        .read(seriesActivePlaybackProvider.notifier)
        .state = const SeriesActivePlayback(
      playlistId: 1,
      seriesStreamId: 'series-a',
      seriesChannelDbId: 201,
      episode: _episodeA,
    );

    expect(container.read(selectedVodGroupFilterProvider), 'Action');
    expect(container.read(selectedSeriesGroupFilterProvider), 'Drama');
    expect(container.read(selectedSeriesChannelProvider), _seriesA);
    expect(container.read(playbackPrepTargetProvider), isNotNull);
    expect(
      container.read(playbackPrepControllerProvider).phase,
      PlaybackPrepPhase.ready,
    );
    expect(container.read(seriesActivePlaybackProvider), isNotNull);

    container.read(selectedPlaylistIdProvider.notifier).state = 2;

    expect(container.read(selectedVodGroupFilterProvider), kAllGroupsFilter);
    expect(container.read(selectedSeriesGroupFilterProvider), kAllGroupsFilter);
    expect(container.read(selectedSeriesChannelProvider), isNull);
    expect(container.read(playbackPrepTargetProvider), isNull);
    expect(
      container.read(playbackPrepControllerProvider),
      const PlaybackPrepState(),
    );
    expect(container.read(seriesActivePlaybackProvider), isNull);
  });
}
