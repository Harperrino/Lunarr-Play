import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

export 'package:m3uxtream_player/core/constants/filter_constants.dart';

/// Active category/group filter. [kAllGroupsFilter] means no filter applied.
final selectedGroupFilterProvider = StateProvider<String>(
  (ref) => kAllGroupsFilter,
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
  final playlistId = ref.watch(selectedPlaylistIdProvider);
  if (playlistId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(playlistRepositoryProvider)
      .watchChannelsByPlaylistAndType(playlistId, 'live');
});

/// Distinct group names derived from live channels in the active playlist.
final channelGroupsProvider = Provider.autoDispose<List<String>>((ref) {
  final channelsAsync = ref.watch(liveChannelsStreamProvider);
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

/// Live channels after applying the active group filter.
final filteredChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels =
      ref.watch(liveChannelsStreamProvider).valueOrNull ?? const [];
  final groupFilter = ref.watch(selectedGroupFilterProvider);
  final hidden = ref.watch(hiddenGroupsProvider).valueOrNull ?? const {};
  final search = ref.watch(debouncedGlobalSearchQueryProvider);
  return filterChannels(
    channels: channels,
    groupFilter: groupFilter,
    hiddenGroups: hidden,
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
  ChannelFavoriteController(
    this._toggleFavorite, {
    Stream<List<Channel>>? channelStream,
  }) : _channelStream = channelStream,
       super(const ChannelFavoriteMutationState()) {
    if (channelStream != null) {
      _channelSubscription = channelStream.listen(_reconcile);
    }
  }

  final Future<bool> Function(int channelId) _toggleFavorite;
  final Stream<List<Channel>>? _channelStream;
  StreamSubscription<List<Channel>>? _channelSubscription;

  @override
  void dispose() {
    _channelSubscription?.cancel();
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
      await _toggleFavorite(channelId);
      if (_channelStream == null) {
        busy.remove(channelId);
        state = state.copyWith(
          busyChannelIds: busy,
          optimisticFavorites: overrides,
          error: null,
        );
      }
    } catch (error) {
      overrides.remove(channelId);
      busy.remove(channelId);
      state = state.copyWith(
        busyChannelIds: busy,
        optimisticFavorites: overrides,
        error: error,
      );
    }
  }

  void _reconcile(List<Channel> channels) {
    if (state.optimisticFavorites.isEmpty) return;
    final overrides = {...state.optimisticFavorites};
    final busy = {...state.busyChannelIds};
    var changed = false;

    for (final channel in channels) {
      final expected = overrides[channel.id];
      if (expected == null || expected != channel.isFavorite) continue;
      overrides.remove(channel.id);
      busy.remove(channel.id);
      changed = true;
    }

    if (changed) {
      state = state.copyWith(
        busyChannelIds: busy,
        optimisticFavorites: overrides,
        error: state.error,
      );
    }
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
        channelStream: ref.read(playlistRepositoryProvider).watchAllChannels(),
      );
    });

/// VOD movies for the active playlist (M6B UI).
final vodChannelsStreamProvider = StreamProvider.autoDispose<List<Channel>>((
  ref,
) {
  final playlistId = ref.watch(selectedPlaylistIdProvider);
  if (playlistId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(playlistRepositoryProvider)
      .watchChannelsByPlaylistAndType(playlistId, 'vod');
});

/// Series catalogue for the active playlist (M6C UI).
final seriesChannelsStreamProvider = StreamProvider.autoDispose<List<Channel>>((
  ref,
) {
  final playlistId = ref.watch(selectedPlaylistIdProvider);
  if (playlistId == null) {
    return Stream.value(const []);
  }
  return ref
      .watch(playlistRepositoryProvider)
      .watchChannelsByPlaylistAndType(playlistId, 'series');
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
