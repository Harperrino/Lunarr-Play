import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

/// Compatibility-only stream retained for older test and feature boundaries.
/// Production search reads only [SearchHit] rows from [SearchIndexRepository]
/// and never materializes the channel catalogue in Dart.
final globalSearchChannelsStreamProvider =
    StreamProvider.autoDispose<List<SearchCatalogEntry>>((ref) {
      return Stream.value(const []);
    });

final searchCatalogStreamProvider = globalSearchChannelsStreamProvider;

/// Compatibility projection for callers that still observe the old catalogue
/// provider. It is intentionally empty; all live search work uses SQLite FTS.
final searchCatalogIndexProvider =
    Provider.autoDispose<AsyncValue<List<SearchCatalogEntry>>>((ref) {
      return ref.watch(globalSearchChannelsStreamProvider);
    });

final searchIndexBuildStateProvider =
    StreamProvider.autoDispose<SearchIndexBuildState>((ref) {
      return ref.read(searchIndexRepositoryProvider).watchIndexBuildState();
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

/// Asynchronous SQLite search boundary. Riverpod disposes an obsolete query
/// computation when the debounced text changes, so an older result cannot
/// replace a newer one in the dropdown.
final globalSearchResultsAsyncProvider =
    FutureProvider.autoDispose<GlobalSearchResults>((ref) async {
      final session = ref.watch(searchOverlaySessionProvider);
      final query = ref.watch(debouncedGlobalSearchQueryProvider).trim();
      final filter = ref.watch(searchOverlayFilterProvider);
      if (!session.isOpen || query.isEmpty) return _emptySearchResults;

      var active = true;
      ref.onDispose(() => active = false);

      final playlists = await ref.watch(playlistsStreamProvider.future);
      final inactiveIds = await ref.watch(inactivePlaylistIdsProvider.future);
      final activePlaylists = playlists
          .where((playlist) => !inactiveIds.contains(playlist.id))
          .toList(growable: false);
      if (!active || activePlaylists.isEmpty) return _emptySearchResults;

      final hiddenByPlaylist = <int, Set<String>>{};
      final pinnedByPlaylist = <int, Set<String>>{};
      final metadata = await Future.wait(
        activePlaylists.map((playlist) async {
          final hidden = await ref.watch(
            hiddenGroupsForPlaylistProvider(playlist.id).future,
          );
          final pinned = await ref.watch(
            pinnedGroupsForPlaylistProvider(playlist.id).future,
          );
          return (
            playlistId: playlist.id,
            hidden: hidden,
            pinned: pinned.toSet(),
          );
        }),
      );
      for (final entry in metadata) {
        hiddenByPlaylist[entry.playlistId] = entry.hidden;
        pinnedByPlaylist[entry.playlistId] = entry.pinned;
      }

      final hits = await ref
          .read(searchIndexRepositoryProvider)
          .search(
            SearchRequest(
              query: query,
              tab: _searchResultTabFor(filter),
              activePlaylistIds: activePlaylists
                  .map((playlist) => playlist.id)
                  .toSet(),
              hiddenGroupsByPlaylist: hiddenByPlaylist,
              pinnedGroupsByPlaylist: pinnedByPlaylist,
              limit: 12,
            ),
          );
      if (!active) return _emptySearchResults;

      final matchingIndex = ref.watch(epgMatchingIndexProvider);
      final channels = <ChannelSearchResult>[];
      final categories = <CategorySearchResult>[];
      for (final hit in hits) {
        if (hit.type == SearchHitType.channel && hit.channelId != null) {
          final entry = SearchCatalogEntry(
            channelId: hit.channelId!,
            playlistId: hit.playlistId,
            type: hit.mediaType,
            name: hit.title,
            category: hit.category,
            epgChannelId: hit.epgChannelId,
          );
          channels.add(
            ChannelSearchResult(
              entry: entry,
              playlistId: hit.playlistId,
              playlistName: hit.playlistName,
              categoryName: hit.category,
              resolvedEpgChannelId: matchingIndex
                  .matchCatalogEntry(entry)
                  .resolvedEpgChannelId,
            ),
          );
          continue;
        }

        final target = _targetForChannelType(hit.mediaType);
        if (target == null) continue;
        categories.add(
          CategorySearchResult(
            target: target,
            categoryName: hit.title,
            playlistId: hit.playlistId,
            playlistName: hit.playlistName,
            isPinned: hit.isPinned,
          ),
        );
      }

      return GlobalSearchResults(channels: channels, categories: categories);
    });

/// Synchronous compatibility projection used by existing tab providers.
/// The dropdown itself observes [searchResultsAsyncProvider] for loading and
/// error states.
final globalSearchResultsProvider = Provider.autoDispose<GlobalSearchResults>((
  ref,
) {
  return ref.watch(globalSearchResultsAsyncProvider).valueOrNull ??
      _emptySearchResults;
});

final searchResultsAsyncProvider =
    Provider.autoDispose<AsyncValue<GlobalSearchResults>>((ref) {
      final session = ref.watch(searchOverlaySessionProvider);
      final query = ref.watch(debouncedGlobalSearchQueryProvider).trim();
      if (!session.isOpen || query.isEmpty) {
        return const AsyncData(_emptySearchResults);
      }
      // This is deliberately a projection of the one canonical async
      // provider. It must never read globalSearchResultsProvider while that
      // provider is itself reading the async query.
      return ref.watch(globalSearchResultsAsyncProvider);
    });

final channelSearchResultsProvider =
    Provider.autoDispose<List<ChannelSearchResult>>((ref) {
      return ref.watch(globalSearchResultsProvider).channels;
    });

final categorySearchResultsProvider =
    Provider.autoDispose<List<CategorySearchResult>>((ref) {
      return ref.watch(globalSearchResultsProvider).categories;
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

const _emptySearchResults = GlobalSearchResults(
  channels: <ChannelSearchResult>[],
  categories: <CategorySearchResult>[],
);

CategorySearchTarget? _targetForChannelType(String type) => switch (type) {
  'live' => CategorySearchTarget.live,
  'vod' => CategorySearchTarget.movies,
  'series' => CategorySearchTarget.series,
  _ => null,
};

SearchResultTab _searchResultTabFor(SearchOverlayFilter filter) =>
    switch (filter) {
      SearchOverlayFilter.all => SearchResultTab.all,
      SearchOverlayFilter.channels => SearchResultTab.channels,
      SearchOverlayFilter.categories => SearchResultTab.categories,
    };
