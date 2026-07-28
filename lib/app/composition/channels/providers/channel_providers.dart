import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';

export 'package:m3uxtream_player/core/constants/filter_constants.dart';

/// Active category/group filter. [kAllGroupsFilter] means no filter applied.
final StateProvider<String> selectedGroupFilterProvider = StateProvider<String>(
  (ref) {
    ref.listen<PlaylistCatalogScope?>(playlistCatalogScopeProvider, (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(selectedGroupFilterProvider.notifier).state = kAllGroupsFilter;
      }
    });
    return kAllGroupsFilter;
  },
);

/// Unfiltered reactive channel stream for the selected playlist (all types).
final channelsStreamProvider = StreamProvider.autoDispose<List<Channel>>((ref) {
  final playlistId = ref.watch(selectedPlaylistIdProvider);
  if (playlistId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(playlistRepositoryProvider)
      .watchChannelsByPlaylist(playlistId);
});

/// Live channels only — used by Live tab, EPG grid, and keyboard navigation.
final liveChannelsStreamProvider = StreamProvider.autoDispose<List<Channel>>((
  ref,
) {
  final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
  final query = PlaylistCatalogQuery(
    scope: scope,
    mediaType: PlaylistCatalogMediaType.live,
  );
  return _projectCatalogState(ref.watch(playlistCatalogStreamProvider(query)));
});

/// Projects the canonical family provider without subscribing to its
/// deprecated `.stream` view.
///
/// A nested stream subscription can miss a synchronous warm-cache emission
/// while changing back from All to an already visited concrete scope. Watching
/// the AsyncValue first makes the latest catalogue state replayable; each real
/// family update rebuilds this lightweight compatibility stream.
Stream<List<Channel>> _projectCatalogState(AsyncValue<List<Channel>> catalog) {
  final channels = catalog.valueOrNull;
  if (channels != null) return Stream.value(channels);
  if (catalog.hasError) {
    return Stream.error(catalog.error!, catalog.stackTrace);
  }
  return const Stream<List<Channel>>.empty();
}

/// Typed category entries retain playlist identity in All scope.
final liveCategoryEntriesProvider =
    Provider.autoDispose<List<PlaylistCatalogCategory>>((ref) {
      final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
      return ref.watch(
        playlistCatalogCategoryProvider(
          PlaylistCatalogQuery(
            scope: scope,
            mediaType: PlaylistCatalogMediaType.live,
          ),
        ),
      );
    });

/// Compatibility projection for older callers that only need visible names.
final channelGroupsProvider = Provider.autoDispose<List<String>>((ref) {
  final entries = ref.watch(liveCategoryEntriesProvider);
  return <String>{for (final entry in entries) entry.groupName}.toList();
});

/// Live channels after applying the active group filter.
final filteredChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels =
      ref.watch(liveChannelsStreamProvider).valueOrNull ?? const [];
  final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
  final ids = ref.watch(playlistCatalogPlaylistIdsProvider(scope));
  final hiddenByPlaylist = <int, Set<String>>{
    for (final playlistId in ids)
      playlistId:
          ref.watch(hiddenGroupsForPlaylistProvider(playlistId)).valueOrNull ??
          const <String>{},
  };
  final groupFilter = ref.watch(selectedGroupFilterProvider);
  final search = ref.watch(debouncedGlobalSearchQueryProvider);
  return filterPlaylistCatalogChannels(
    channels: channels,
    groupFilter: groupFilter,
    hiddenGroupsByPlaylist: hiddenByPlaylist,
    searchQuery: search,
  );
});

class ChannelFavoriteMutationState {
  const ChannelFavoriteMutationState({
    this.busyChannelIds = const <int>{},
    this.optimisticFavorites = const <int, bool>{},
    this.error,
  });

  final Set<int> busyChannelIds;
  final Map<int, bool> optimisticFavorites;
  final Object? error;

  bool get isLoading => busyChannelIds.isNotEmpty;
  bool get hasError => error != null;

  bool isBusy(int channelId) => busyChannelIds.contains(channelId);

  bool isFavorite(Channel channel) =>
      optimisticFavorites[channel.id] ?? channel.isFavorite;

  ChannelFavoriteMutationState copyWith({
    required Set<int> busyChannelIds,
    required Map<int, bool> optimisticFavorites,
    Object? error,
  }) {
    return ChannelFavoriteMutationState(
      busyChannelIds: Set.unmodifiable(busyChannelIds),
      optimisticFavorites: Map.unmodifiable(optimisticFavorites),
      error: error,
    );
  }
}

class ChannelFavoriteController
    extends StateNotifier<ChannelFavoriteMutationState> {
  ChannelFavoriteController(this._toggleFavorite, {this._watchChannelById})
    : super(const ChannelFavoriteMutationState());

  final Future<bool> Function(int channelId) _toggleFavorite;
  final Stream<Channel> Function(int channelId)? _watchChannelById;
  final Map<int, StreamSubscription<Channel>> _channelSubscriptions = {};

  @override
  void dispose() {
    for (final subscription in _channelSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _channelSubscriptions.clear();
    super.dispose();
  }

  Future<void> toggle(int channelId, {bool? currentFavorite}) async {
    if (state.isBusy(channelId)) return;

    final overrides = {...state.optimisticFavorites};
    final current = overrides[channelId] ?? currentFavorite ?? false;
    final desired = !current;
    overrides[channelId] = desired;
    final busy = {...state.busyChannelIds, channelId};
    state = state.copyWith(
      busyChannelIds: busy,
      optimisticFavorites: overrides,
      error: null,
    );

    try {
      _subscribeToChannel(channelId);
      await _toggleFavorite(channelId);
      if (_watchChannelById == null) {
        busy.remove(channelId);
        overrides.remove(channelId);
        state = state.copyWith(
          busyChannelIds: busy,
          optimisticFavorites: overrides,
          error: null,
        );
      }
    } catch (error) {
      _cancelChannelSubscription(channelId);
      overrides.remove(channelId);
      busy.remove(channelId);
      state = state.copyWith(
        busyChannelIds: busy,
        optimisticFavorites: overrides,
        error: error,
      );
    }
  }

  void _subscribeToChannel(int channelId) {
    final watchChannelById = _watchChannelById;
    if (watchChannelById == null) return;

    final subscription = watchChannelById(channelId).listen(_reconcile);
    _channelSubscriptions[channelId] = subscription;
    // A synchronous stream may have emitted the already-confirmed value
    // before listen returned. Do not retain that subscription in that case.
    if (!state.optimisticFavorites.containsKey(channelId)) {
      _cancelChannelSubscription(channelId);
    }
  }

  void _reconcile(Channel channel) {
    final expected = state.optimisticFavorites[channel.id];
    if (expected == null || expected != channel.isFavorite) return;

    final overrides = {...state.optimisticFavorites};
    final busy = {...state.busyChannelIds};
    overrides.remove(channel.id);
    busy.remove(channel.id);
    state = state.copyWith(
      busyChannelIds: busy,
      optimisticFavorites: overrides,
      error: state.error,
    );
    _cancelChannelSubscription(channel.id);
  }

  void _cancelChannelSubscription(int channelId) {
    final subscription = _channelSubscriptions.remove(channelId);
    if (subscription != null) unawaited(subscription.cancel());
  }
}

/// Mutation boundary shared by Live and Favorites UI.
final channelFavoriteControllerProvider =
    StateNotifierProvider.autoDispose<
      ChannelFavoriteController,
      ChannelFavoriteMutationState
    >((ref) {
      return ChannelFavoriteController(
        ref.read(playlistRepositoryProvider).toggleChannelFavorite,
        watchChannelById: ref.read(playlistRepositoryProvider).watchChannelById,
      );
    });

/// VOD movies for the active playlist (M6B UI).
final vodChannelsStreamProvider = StreamProvider.autoDispose<List<Channel>>((
  ref,
) {
  final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
  final query = PlaylistCatalogQuery(
    scope: scope,
    mediaType: PlaylistCatalogMediaType.vod,
  );
  return _projectCatalogState(ref.watch(playlistCatalogStreamProvider(query)));
});

/// Series catalogue for the active playlist (M6C UI).
final seriesChannelsStreamProvider = StreamProvider.autoDispose<List<Channel>>((
  ref,
) {
  final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
  final query = PlaylistCatalogQuery(
    scope: scope,
    mediaType: PlaylistCatalogMediaType.series,
  );
  return _projectCatalogState(ref.watch(playlistCatalogStreamProvider(query)));
});

/// Manual Watch Later entries for the active playlist (VOD + series titles).
final watchLaterChannelsStreamProvider =
    StreamProvider.autoDispose<List<Channel>>((ref) {
      final playlistId = ref.watch(selectedPlaylistIdProvider);
      if (playlistId == null) {
        return Stream.value(const []);
      }
      return ref
          .watch(playlistRepositoryProvider)
          .watchWatchLaterByPlaylist(playlistId);
    });

final watchLaterChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  return ref.watch(watchLaterChannelsStreamProvider).valueOrNull ?? const [];
});

class ChannelWatchLaterController extends StateNotifier<AsyncValue<void>> {
  ChannelWatchLaterController(this._toggleWatchLater)
    : super(const AsyncValue.data(null));

  final Future<bool> Function(int channelId) _toggleWatchLater;

  Future<void> toggle(int channelId) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _toggleWatchLater(channelId);
    });
  }
}

/// Mutation boundary for the manual Watch Later feature.
final channelWatchLaterControllerProvider =
    StateNotifierProvider.autoDispose<
      ChannelWatchLaterController,
      AsyncValue<void>
    >((ref) {
      return ChannelWatchLaterController(
        ref.read(playlistRepositoryProvider).toggleChannelWatchLater,
      );
    });
