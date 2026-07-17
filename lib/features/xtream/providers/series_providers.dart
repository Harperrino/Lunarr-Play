import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/core/services/series_episode_service.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

/// Active series genre/group filter.
final StateProvider<String> selectedSeriesGroupFilterProvider =
    StateProvider<String>((ref) {
      ref.listen<int?>(selectedPlaylistIdProvider, (previous, next) {
        if (previous != next) {
          ref.read(selectedSeriesGroupFilterProvider.notifier).state =
              kAllGroupsFilter;
        }
      });
      return kAllGroupsFilter;
    });

/// Series selected for the episode detail view (null = catalogue grid).
final StateProvider<Channel?> selectedSeriesChannelProvider =
    StateProvider<Channel?>((ref) {
      ref.listen<int?>(selectedPlaylistIdProvider, (previous, next) {
        if (previous != next) {
          ref.read(selectedSeriesChannelProvider.notifier).state = null;
        }
      });
      return null;
    });

/// Distinct genres from series entries in the active playlist.
final seriesGroupsProvider = Provider.autoDispose<List<String>>((ref) {
  final channelsAsync = ref.watch(seriesChannelsStreamProvider);
  final hidden = ref.watch(hiddenGroupsProvider).valueOrNull ?? {};
  final pinned =
      ref.watch(pinnedGroupsProvider).valueOrNull ?? const <String>[];
  return channelsAsync.when(
    data: (channels) => prioritizePinnedGroups(
      visibleGroups(distinctSortedGroups(channels), hidden),
      pinned,
    ),
    loading: () => const [],
    error: (_, _) => const [],
  );
});

/// Series catalogue after genre filter.
final filteredSeriesChannelsProvider = Provider.autoDispose<List<Channel>>((
  ref,
) {
  final channels =
      ref.watch(seriesChannelsStreamProvider).valueOrNull ?? const [];
  final hidden = ref.watch(hiddenGroupsProvider).valueOrNull ?? const {};
  final search = ref.watch(debouncedGlobalSearchQueryProvider);
  return filterChannels(
    channels: channels,
    groupFilter: ref.watch(selectedSeriesGroupFilterProvider),
    hiddenGroups: hidden,
    searchQuery: search,
  );
});

final seriesChannelsProvider = filteredSeriesChannelsProvider;

final seriesEpisodeServiceProvider = Provider<SeriesEpisodeService>((ref) {
  return SeriesEpisodeService();
});

/// Lazy episode list for a series channel (Xtream API or M3U direct play).
final seriesEpisodesProvider = FutureProvider.autoDispose
    .family<List<ParsedSeriesEpisode>, int>((ref, channelDbId) async {
      final playlistId = ref.watch(selectedPlaylistIdProvider);
      if (playlistId == null) return const [];

      final seriesChannel = _findSeriesChannel(
        ref.watch(seriesChannelsStreamProvider).valueOrNull ?? const [],
        channelDbId,
      );
      if (seriesChannel == null) return const [];

      final playlist = await ref
          .read(playlistRepositoryProvider)
          .getPlaylistById(playlistId);
      if (playlist == null) return const [];

      return ref
          .read(seriesEpisodeServiceProvider)
          .loadEpisodes(seriesChannel: seriesChannel, playlist: playlist);
    });

/// Saved resume point for a series channel.
final seriesResumeProvider = FutureProvider.autoDispose
    .family<SeriesResumeState?, int>((ref, channelDbId) async {
      final playlistId = ref.watch(selectedPlaylistIdProvider);
      if (playlistId == null) return null;

      final seriesChannel = _findSeriesChannel(
        ref.watch(seriesChannelsStreamProvider).valueOrNull ?? const [],
        channelDbId,
      );
      final seriesStreamId = seriesChannel?.streamId;
      if (seriesStreamId == null || seriesStreamId.isEmpty) return null;

      return ref
          .read(appStateRepositoryProvider)
          .getSeriesResume(playlistId, seriesStreamId);
    });

/// Active series episode playback — used by [SeriesResumeTracker] to persist progress.
class SeriesActivePlayback {
  const SeriesActivePlayback({
    required this.playlistId,
    required this.seriesStreamId,
    required this.seriesChannelDbId,
    required this.episode,
  });

  final int playlistId;
  final String seriesStreamId;
  final int seriesChannelDbId;
  final ParsedSeriesEpisode episode;
}

final seriesActivePlaybackProvider = StateProvider<SeriesActivePlayback?>(
  (ref) => null,
);

Channel? _findSeriesChannel(List<Channel> channels, int channelDbId) {
  for (final channel in channels) {
    if (channel.id == channelDbId) return channel;
  }
  return null;
}

List<Channel> filterSeriesChannelsByGroup(
  List<Channel> channels,
  String groupFilter,
) => filterChannelsByGroup(channels, groupFilter);

/// Groups [episodes] by season number for the detail UI.
Map<int, List<ParsedSeriesEpisode>> groupEpisodesBySeason(
  List<ParsedSeriesEpisode> episodes,
) {
  final grouped = <int, List<ParsedSeriesEpisode>>{};
  for (final episode in episodes) {
    final season = episode.season ?? 0;
    grouped.putIfAbsent(season, () => []).add(episode);
  }
  for (final list in grouped.values) {
    list.sort((a, b) => (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0));
  }
  return Map.fromEntries(
    grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

String formatEpisodeSubtitle(ParsedSeriesEpisode episode) {
  if (episode.season != null && episode.episodeNum != null) {
    return 'S${episode.season!.toString().padLeft(2, '0')}E${episode.episodeNum!.toString().padLeft(2, '0')}';
  }
  return episode.title;
}

Future<void> saveSeriesResumeData({
  required AppStateRepository repository,
  required SeriesActivePlayback playback,
  required int positionMs,
}) async {
  await repository.setSeriesResume(
    playback.playlistId,
    playback.seriesStreamId,
    SeriesResumeState(
      episodeId: playback.episode.episodeId,
      episodeTitle: playback.episode.title,
      streamUrl: playback.episode.streamUrl,
      positionMs: positionMs,
      season: playback.episode.season,
      episodeNum: playback.episode.episodeNum,
    ),
  );
}

Future<void> saveSeriesResume(
  WidgetRef ref, {
  required SeriesActivePlayback playback,
  required int positionMs,
}) async {
  await saveSeriesResumeData(
    repository: ref.read(appStateRepositoryProvider),
    playback: playback,
    positionMs: positionMs,
  );
  ref.invalidate(seriesResumeProvider(playback.seriesChannelDbId));
}
