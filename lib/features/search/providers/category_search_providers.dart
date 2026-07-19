import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

/// One shared Drift stream for global search. Active/inactive playlist and
/// hidden-category filtering happen in memory above this boundary.
final globalSearchChannelsStreamProvider =
    StreamProvider.autoDispose<List<Channel>>((ref) {
      return ref.watch(playlistRepositoryProvider).watchAllChannels();
    });

final searchHiddenGroupsForPlaylistProvider = FutureProvider.autoDispose
    .family<Set<String>, int>((ref, playlistId) {
      return ref.read(appStateRepositoryProvider).getHiddenGroups(playlistId);
    });

final searchPinnedGroupsForPlaylistProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, playlistId) {
      return ref.read(appStateRepositoryProvider).getPinnedGroups(playlistId);
    });

final searchOverlayFilterProvider = StateProvider<SearchOverlayFilter>(
  (ref) => SearchOverlayFilter.all,
);

final channelSearchResultsProvider =
    Provider.autoDispose<List<ChannelSearchResult>>((ref) {
      final query = ref.watch(globalSearchQueryProvider);
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return const [];

      final playlists =
          ref.watch(playlistsStreamProvider).valueOrNull ?? const [];
      final inactiveIds =
          ref.watch(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
      final playlistNames = {
        for (final playlist in playlists) playlist.id: playlist.name,
      };
      final activeIds = playlistNames.keys
          .where((playlistId) => !inactiveIds.contains(playlistId))
          .toSet();
      if (activeIds.isEmpty) return const [];

      final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
      final hiddenByPlaylist = <int, Set<String>?>{
        for (final playlistId in activeIds)
          playlistId: _hiddenGroupsForPlaylist(
            ref,
            playlistId,
            selectedPlaylistId,
          ),
      };
      if (hiddenByPlaylist.values.any((hidden) => hidden == null)) {
        return const [];
      }
      final channels =
          ref.watch(globalSearchChannelsStreamProvider).valueOrNull ??
          const <Channel>[];
      final matchingIndex = ref.watch(epgMatchingIndexProvider);
      final scored = <_ScoredChannelSearchResult>[];

      for (final channel in channels) {
        if (channel.channelType != 'live' ||
            !activeIds.contains(channel.playlistId)) {
          continue;
        }

        final hidden = hiddenByPlaylist[channel.playlistId]!;
        if (hidden.contains(normalizeGroupName(channel.groupName))) continue;

        final name = channel.name.trim().toLowerCase();
        final relevance = _matchRelevance(name, normalizedQuery);
        if (relevance == null) continue;

        scored.add(
          _ScoredChannelSearchResult(
            relevance: relevance,
            result: ChannelSearchResult(
              channel: channel,
              playlistId: channel.playlistId,
              playlistName:
                  playlistNames[channel.playlistId] ??
                  'Playlist ${channel.playlistId}',
              categoryName: normalizeGroupName(channel.groupName),
              resolvedEpgChannelId: matchingIndex
                  .matchChannel(channel)
                  .resolvedEpgChannelId,
            ),
          ),
        );
      }

      scored.sort((a, b) {
        final relevance = a.relevance.compareTo(b.relevance);
        if (relevance != 0) return relevance;
        final name = a.result.channel.name.toLowerCase().compareTo(
          b.result.channel.name.toLowerCase(),
        );
        if (name != 0) return name;
        final playlist = a.result.playlistName.toLowerCase().compareTo(
          b.result.playlistName.toLowerCase(),
        );
        if (playlist != 0) return playlist;
        return a.result.channel.id.compareTo(b.result.channel.id);
      });

      return scored
          .take(12)
          .map((entry) => entry.result)
          .toList(growable: false);
    });

final categorySearchResultsProvider =
    Provider.autoDispose<List<CategorySearchResult>>((ref) {
      final query = ref.watch(globalSearchQueryProvider);
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return const [];

      final playlists =
          ref.watch(playlistsStreamProvider).valueOrNull ?? const [];
      final inactiveIds =
          ref.watch(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
      final playlistNames = {
        for (final playlist in playlists) playlist.id: playlist.name,
      };
      final activeIds = playlistNames.keys
          .where((playlistId) => !inactiveIds.contains(playlistId))
          .toSet();
      if (activeIds.isEmpty) return const [];

      final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
      final channels =
          ref.watch(globalSearchChannelsStreamProvider).valueOrNull ??
          const <Channel>[];
      final candidates = <CategorySearchResult>[];
      final seen = <String>{};
      final hiddenByPlaylist = <int, Set<String>?>{
        for (final playlistId in activeIds)
          playlistId: _hiddenGroupsForPlaylist(
            ref,
            playlistId,
            selectedPlaylistId,
          ),
      };
      if (hiddenByPlaylist.values.any((hidden) => hidden == null)) {
        return const [];
      }
      final pinnedByPlaylist = <int, List<String>>{};

      for (final channel in channels) {
        if (!activeIds.contains(channel.playlistId)) continue;
        final categoryName = normalizeGroupName(channel.groupName);
        if (categoryName == kAllGroupsFilter) continue;

        final hidden = hiddenByPlaylist[channel.playlistId]!;
        if (hidden.contains(categoryName)) continue;

        final target = _targetForChannelType(channel.channelType);
        if (target == null) continue;
        final identity = '${channel.playlistId}|${target.name}|$categoryName';
        if (!seen.add(identity)) continue;

        final pinned = pinnedByPlaylist.putIfAbsent(
          channel.playlistId,
          () => _pinnedGroupsForPlaylist(
            ref,
            channel.playlistId,
            selectedPlaylistId,
          ),
        );
        candidates.add(
          CategorySearchResult(
            target: target,
            categoryName: categoryName,
            playlistId: channel.playlistId,
            playlistName:
                playlistNames[channel.playlistId] ??
                'Playlist ${channel.playlistId}',
            isPinned: pinned.contains(categoryName),
          ),
        );
      }

      return matchCategorySearchResults(query: query, candidates: candidates);
    });

final globalSearchResultsProvider = Provider.autoDispose<GlobalSearchResults>((
  ref,
) {
  return GlobalSearchResults(
    channels: ref.watch(channelSearchResultsProvider),
    categories: ref.watch(categorySearchResultsProvider),
  );
});

final searchVisibleChannelResultsProvider =
    Provider.autoDispose<List<ChannelSearchResult>>((ref) {
      final filter = ref.watch(searchOverlayFilterProvider);
      final items = ref.watch(globalSearchResultsProvider).itemsFor(filter);
      return items
          .map((item) => item.channel)
          .whereType<ChannelSearchResult>()
          .toList(growable: false);
    });

enum SearchEpgLineState { current, noEpg }

class SearchEpgLine {
  const SearchEpgLine.current(this.title) : state = SearchEpgLineState.current;
  const SearchEpgLine.noEpg() : state = SearchEpgLineState.noEpg, title = null;

  final SearchEpgLineState state;
  final String? title;
}

final searchEpgMinuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  late final StreamController<DateTime> controller;
  Timer? timer;

  void scheduleTick() {
    if (controller.isClosed) return;
    final now = DateTime.now();
    controller.add(now);
    final elapsed = Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );
    timer?.cancel();
    timer = Timer(const Duration(minutes: 1) - elapsed, scheduleTick);
  }

  controller = StreamController<DateTime>(onListen: scheduleTick);
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

final searchEpgLinesProvider =
    StreamProvider.autoDispose<Map<int, SearchEpgLine>>((ref) {
      final minuteTick = ref.watch(searchEpgMinuteTickProvider);
      if (minuteTick.isLoading) {
        return const Stream<Map<int, SearchEpgLine>>.empty();
      }
      final results = ref
          .watch(searchVisibleChannelResultsProvider)
          .take(12)
          .toList(growable: false);
      final resolvedIds = {
        for (final result in results)
          if (result.resolvedEpgChannelId != null)
            result.resolvedEpgChannelId!: result.channelId,
      };

      if (resolvedIds.isEmpty) {
        return Stream.value({
          for (final result in results)
            result.channelId: const SearchEpgLine.noEpg(),
        });
      }

      final now = DateTime.now();
      return ref
          .read(epgRepositoryProvider)
          .watchEntriesInRangeForChannelIds(
            resolvedIds.keys.toList(growable: false),
            now.subtract(const Duration(minutes: 1)),
            now.add(const Duration(minutes: 1)),
          )
          .map((entries) {
            final currentByEpgId = <String, EpgEntry>{};
            for (final entry in entries) {
              if (!entry.startTime.isAfter(now) && entry.endTime.isAfter(now)) {
                currentByEpgId.putIfAbsent(entry.channelId, () => entry);
              }
            }

            return {
              for (final result in results)
                result.channelId: _lineForResult(result, currentByEpgId),
            };
          });
    });

SearchEpgLine _lineForResult(
  ChannelSearchResult result,
  Map<String, EpgEntry> currentByEpgId,
) {
  final resolvedId = result.resolvedEpgChannelId;
  final entry = resolvedId == null ? null : currentByEpgId[resolvedId];
  return entry == null
      ? const SearchEpgLine.noEpg()
      : SearchEpgLine.current(entry.title);
}

Set<String>? _hiddenGroupsForPlaylist(
  Ref ref,
  int playlistId,
  int? selectedPlaylistId,
) {
  if (playlistId == selectedPlaylistId) {
    final hidden = ref.watch(hiddenGroupsProvider);
    if (hidden.isLoading) return null;
    return hidden.valueOrNull ?? const <String>{};
  }
  final hidden = ref.watch(searchHiddenGroupsForPlaylistProvider(playlistId));
  if (hidden.isLoading) return null;
  return hidden.valueOrNull ?? const <String>{};
}

List<String> _pinnedGroupsForPlaylist(
  Ref ref,
  int playlistId,
  int? selectedPlaylistId,
) {
  if (playlistId == selectedPlaylistId) {
    return ref.watch(pinnedGroupsProvider).valueOrNull ?? const <String>[];
  }
  return ref
          .watch(searchPinnedGroupsForPlaylistProvider(playlistId))
          .valueOrNull ??
      const <String>[];
}

CategorySearchTarget? _targetForChannelType(String type) => switch (type) {
  'live' => CategorySearchTarget.live,
  'vod' => CategorySearchTarget.movies,
  'series' => CategorySearchTarget.series,
  _ => null,
};

int? _matchRelevance(String value, String query) {
  if (value == query) return 0;
  if (value.startsWith(query)) return 1;
  if (value.contains(query)) return 2;
  return null;
}

class _ScoredChannelSearchResult {
  const _ScoredChannelSearchResult({
    required this.relevance,
    required this.result,
  });

  final int relevance;
  final ChannelSearchResult result;
}
