import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/cache/bounded_value_cache.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/models/playlist_catalog_scope.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

export 'package:m3uxtream_player/core/models/playlist_catalog_scope.dart';

/// Null means “follow the concrete selected playlist”. The explicit All
/// value survives ordinary playback/detail selection changes.
final playlistCatalogScopeProvider = StateProvider<PlaylistCatalogScope?>(
  (ref) => null,
);

/// Compatibility alias for callers that use the shorter name.
final catalogScopeProvider = playlistCatalogScopeProvider;

final effectivePlaylistCatalogScopeProvider = Provider<PlaylistCatalogScope>((
  ref,
) {
  final explicit = ref.watch(playlistCatalogScopeProvider);
  if (explicit != null) return explicit;
  final selected = ref.watch(selectedPlaylistIdProvider);
  return selected == null
      ? const PlaylistCatalogScope.allActive()
      : PlaylistCatalogScope.single(selected);
});

/// Playlist IDs in provider order. All scope uses only active IDs, while a
/// single scope remains a concrete playlist boundary.
final playlistCatalogPlaylistIdsProvider =
    Provider.family<List<int>, PlaylistCatalogScope>((ref, scope) {
      final playlists =
          ref.watch(playlistsStreamProvider).valueOrNull ?? const <Playlist>[];
      final inactive =
          ref.watch(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
      if (scope.isAllActive) {
        return [
          for (final playlist in playlists)
            if (!inactive.contains(playlist.id)) playlist.id,
        ];
      }
      final playlistId = scope.playlistId;
      if (playlistId == null) return const [];
      return playlists.any((playlist) => playlist.id == playlistId)
          ? [playlistId]
          : const [];
    });

final playlistCatalogPlaylistOrderProvider =
    Provider.family<List<int>, PlaylistCatalogScope>((ref, scope) {
      return ref.watch(playlistCatalogPlaylistIdsProvider(scope));
    });

final playlistCatalogWarmCacheProvider = Provider<PlaylistCatalogWarmCache>(
  (ref) => PlaylistCatalogWarmCache(),
);

final playlistCatalogProjectionCacheProvider =
    Provider<BoundedValueCache<PlaylistCatalogProjectionKey, List<Channel>>>(
      (ref) => BoundedValueCache(maxEntries: 24),
    );

final playlistCatalogCategoryProjectionCacheProvider =
    Provider<
      BoundedValueCache<
        PlaylistCatalogCategoryProjectionKey,
        List<PlaylistCatalogCategory>
      >
    >((ref) => BoundedValueCache(maxEntries: 24));

class PlaylistCatalogProjectionKey {
  const PlaylistCatalogProjectionKey({
    required this.catalog,
    required this.scope,
    required this.mediaType,
    required this.groupFilter,
    required this.searchQuery,
    required this.hiddenFingerprint,
  });

  final List<Channel> catalog;
  final PlaylistCatalogScope scope;
  final PlaylistCatalogMediaType mediaType;
  final String groupFilter;
  final String searchQuery;
  final int hiddenFingerprint;

  @override
  bool operator ==(Object other) =>
      other is PlaylistCatalogProjectionKey &&
      identical(other.catalog, catalog) &&
      other.scope == scope &&
      other.mediaType == mediaType &&
      other.groupFilter == groupFilter &&
      other.searchQuery == searchQuery &&
      other.hiddenFingerprint == hiddenFingerprint;

  @override
  int get hashCode => Object.hash(
    identityHashCode(catalog),
    scope,
    mediaType,
    groupFilter,
    searchQuery,
    hiddenFingerprint,
  );
}

class PlaylistCatalogCategoryProjectionKey {
  const PlaylistCatalogCategoryProjectionKey({
    required this.catalog,
    required this.scope,
    required this.hiddenFingerprint,
    required this.pinnedFingerprint,
    required this.namesFingerprint,
  });

  final List<Channel> catalog;
  final PlaylistCatalogScope scope;
  final int hiddenFingerprint;
  final int pinnedFingerprint;
  final int namesFingerprint;

  @override
  bool operator ==(Object other) =>
      other is PlaylistCatalogCategoryProjectionKey &&
      identical(other.catalog, catalog) &&
      other.scope == scope &&
      other.hiddenFingerprint == hiddenFingerprint &&
      other.pinnedFingerprint == pinnedFingerprint &&
      other.namesFingerprint == namesFingerprint;

  @override
  int get hashCode => Object.hash(
    identityHashCode(catalog),
    scope,
    hiddenFingerprint,
    pinnedFingerprint,
    namesFingerprint,
  );
}

int playlistCatalogSetMapFingerprint(Map<int, Set<String>> values) {
  final ids = values.keys.toList()..sort();
  return Object.hashAll([
    for (final id in ids) ...[
      id,
      ...((values[id] ?? const <String>{}).toList()..sort()),
    ],
  ]);
}

int playlistCatalogListMapFingerprint(Map<int, List<String>> values) {
  final ids = values.keys.toList()..sort();
  return Object.hashAll([
    for (final id in ids) ...[id, ...(values[id] ?? const <String>[])],
  ]);
}

int playlistCatalogNamesFingerprint(Map<int, String> values) {
  final ids = values.keys.toList()..sort();
  return Object.hashAll([
    for (final id in ids) ...[id, values[id]],
  ]);
}

List<Channel> cachedPlaylistCatalogProjection({
  required BoundedValueCache<PlaylistCatalogProjectionKey, List<Channel>> cache,
  required List<Channel> channels,
  required PlaylistCatalogScope scope,
  required PlaylistCatalogMediaType mediaType,
  required String groupFilter,
  required Map<int, Set<String>> hiddenGroupsByPlaylist,
  required String searchQuery,
}) {
  final key = PlaylistCatalogProjectionKey(
    catalog: channels,
    scope: scope,
    mediaType: mediaType,
    groupFilter: groupFilter,
    searchQuery: searchQuery,
    hiddenFingerprint: playlistCatalogSetMapFingerprint(hiddenGroupsByPlaylist),
  );
  return cache.getOrCompute(
    key,
    () => filterPlaylistCatalogChannels(
      channels: channels,
      groupFilter: groupFilter,
      hiddenGroupsByPlaylist: hiddenGroupsByPlaylist,
      searchQuery: searchQuery,
    ),
  );
}

class PlaylistCatalogWarmCache {
  /// Keeps a modest working set across Live, movie and series catalogues.
  ///
  /// Four entries were enough for `All + 3 playlists` only while no other
  /// media catalogue was visited. A VOD/series entry then evicted a Live
  /// playlist and turned ordinary top-bar switching into a cold SQLite load.
  static const maxEntries = 16;

  final LinkedHashMap<PlaylistCatalogQuery, List<Channel>> _entries =
      LinkedHashMap<PlaylistCatalogQuery, List<Channel>>();
  final Map<PlaylistCatalogQuery, int> _generations = {};

  List<Channel>? read(PlaylistCatalogQuery query) {
    final value = _entries.remove(query);
    if (value == null) return null;
    _entries[query] = value;
    return value;
  }

  void write(
    PlaylistCatalogQuery query,
    List<Channel> channels, {
    Iterable<int> coveredPlaylistIds = const <int>[],
  }) {
    if (query.scope.isAllActive) {
      // The All-active result already contains the complete data needed by
      // every concrete scope. Partition it once so switching through the
      // top-bar playlists can paint from memory instead of issuing another
      // cold query for thousands of rows per first visit.
      final byPlaylist = <int, List<Channel>>{
        for (final playlistId in coveredPlaylistIds) playlistId: <Channel>[],
      };
      for (final channel in channels) {
        (byPlaylist[channel.playlistId] ??= <Channel>[]).add(channel);
      }
      for (final entry in byPlaylist.entries) {
        _writeEntry(
          PlaylistCatalogQuery(
            scope: PlaylistCatalogScope.single(entry.key),
            mediaType: query.mediaType,
          ),
          entry.value,
        );
      }
    }
    // Write All last so a catalogue with more playlists than the bounded
    // working set retains the synthetic scope as the most recent entry.
    _writeEntry(query, channels);
  }

  void _writeEntry(PlaylistCatalogQuery query, List<Channel> channels) {
    _entries.remove(query);
    _entries[query] = List<Channel>.unmodifiable(channels);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Starts a new generation for exactly one `(scope, media type)` query.
  ///
  /// Generations must never be shared by media type alone: during a
  /// single-to-All transition both streams can briefly overlap. A late
  /// generation from the outgoing scope must not invalidate the incoming
  /// All-scope stream before its first SQLite value arrives.
  int nextGeneration(PlaylistCatalogQuery query) {
    final next = (_generations[query] ?? 0) + 1;
    _generations[query] = next;
    return next;
  }

  bool isCurrent(PlaylistCatalogQuery query, int generation) =>
      _generations[query] == generation;

  /// Targeted invalidation: drops every cached entry whose scope covers
  /// [playlistId] — the synthetic All scope and the concrete single scope.
  /// Entries of unrelated playlists stay warm; the whole cache is never
  /// cleared on routine sync/activity/delete mutations.
  void invalidateForPlaylist(int playlistId) {
    bool coversPlaylist(PlaylistCatalogQuery key) {
      final scope = key.scope;
      return scope.isAllActive || scope.playlistId == playlistId;
    }

    _entries.removeWhere((key, _) => coversPlaylist(key));
    // Mark already-running matching streams stale as well. A rebuilt provider
    // will allocate a fresh generation for the same exact query.
    _generations.removeWhere((key, _) => coversPlaylist(key));
  }
}

/// Stream family keyed only by (scope, media type); the active ID list is
/// applied directly in the repository query and never merged in the UI.
final playlistCatalogStreamProvider = StreamProvider.autoDispose
    .family<List<Channel>, PlaylistCatalogQuery>((ref, query) {
      final ids = ref.watch(playlistCatalogPlaylistIdsProvider(query.scope));
      final cache = ref.read(playlistCatalogWarmCacheProvider);
      final repository = ref.watch(playlistRepositoryProvider);
      return watchPlaylistCatalog(
        repository: repository,
        cache: cache,
        query: query,
        playlistIds: ids,
      );
    });

Stream<List<Channel>> watchPlaylistCatalog({
  required PlaylistRepository repository,
  required PlaylistCatalogWarmCache cache,
  required PlaylistCatalogQuery query,
  required List<int> playlistIds,
}) {
  if (playlistIds.isEmpty) return Stream.value(const <Channel>[]);

  final cached = cache.read(query);
  final generation = cache.nextGeneration(query);
  return Stream.multi((controller) {
    if (cached != null) controller.add(cached);
    final subscription = repository
        .watchChannelsByPlaylistIdsAndType(
          playlistIds,
          query.mediaType.databaseValue,
        )
        .listen((channels) {
          if (!cache.isCurrent(query, generation)) return;
          cache.write(query, channels, coveredPlaylistIds: playlistIds);
          controller.add(channels);
        }, onError: controller.addError);
    controller.onCancel = subscription.cancel;
  });
}

/// Reads a playlist-name map once for All-scope category subtitles.
final playlistNamesByIdProvider = Provider<Map<int, String>>((ref) {
  final playlists =
      ref.watch(playlistsStreamProvider).valueOrNull ?? const <Playlist>[];
  return {for (final playlist in playlists) playlist.id: playlist.name};
});

/// Current scope's playlist-specific category metadata. The visibility and
/// pin maps are loaded through family providers in the feature layer.
final playlistCatalogCategoryProvider =
    Provider.family<List<PlaylistCatalogCategory>, PlaylistCatalogQuery>((
      ref,
      query,
    ) {
      final channels =
          ref.watch(playlistCatalogStreamProvider(query)).valueOrNull ??
          const <Channel>[];
      final ids = ref.watch(playlistCatalogPlaylistIdsProvider(query.scope));
      final hidden = <int, Set<String>>{
        for (final playlistId in ids)
          playlistId:
              ref
                  .watch(hiddenGroupsForPlaylistProvider(playlistId))
                  .valueOrNull ??
              const <String>{},
      };
      final pinned = <int, List<String>>{
        for (final playlistId in ids)
          playlistId:
              ref
                  .watch(pinnedGroupsForPlaylistProvider(playlistId))
                  .valueOrNull ??
              const <String>[],
      };
      final names = ref.watch(playlistNamesByIdProvider);
      final key = PlaylistCatalogCategoryProjectionKey(
        catalog: channels,
        scope: query.scope,
        hiddenFingerprint: playlistCatalogSetMapFingerprint(hidden),
        pinnedFingerprint: playlistCatalogListMapFingerprint(pinned),
        namesFingerprint: playlistCatalogNamesFingerprint(names),
      );
      return ref
          .read(playlistCatalogCategoryProjectionCacheProvider)
          .getOrCompute(
            key,
            () => buildPlaylistCatalogCategories(
              channels: channels,
              scope: query.scope,
              playlistNamesById: names,
              hiddenGroupsByPlaylist: hidden,
              pinnedGroupsByPlaylist: pinned,
            ),
          );
    });

ChannelSortMode defaultCatalogSortModeFor(PlaylistCatalogScope scope) =>
    ChannelSortMode.providerDefault;
