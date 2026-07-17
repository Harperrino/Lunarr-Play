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

class ChannelFavoriteController extends StateNotifier<AsyncValue<void>> {
  ChannelFavoriteController(this._toggleFavorite)
    : super(const AsyncValue.data(null));

  final Future<bool> Function(int channelId) _toggleFavorite;

  Future<void> toggle(int channelId) async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _toggleFavorite(channelId);
    });
  }
}

/// Mutation boundary shared by Live and Favorites UI.
final channelFavoriteControllerProvider =
    StateNotifierProvider.autoDispose<
      ChannelFavoriteController,
      AsyncValue<void>
    >((ref) {
      return ChannelFavoriteController(
        ref.read(playlistRepositoryProvider).toggleChannelFavorite,
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
