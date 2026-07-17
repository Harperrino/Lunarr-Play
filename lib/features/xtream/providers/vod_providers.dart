import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

/// Active VOD genre/group filter (separate from Live tab group filter).
final StateProvider<String> selectedVodGroupFilterProvider =
    StateProvider<String>((ref) {
      ref.listen<int?>(selectedPlaylistIdProvider, (previous, next) {
        if (previous != next) {
          ref.read(selectedVodGroupFilterProvider.notifier).state =
              kAllGroupsFilter;
        }
      });
      return kAllGroupsFilter;
    });

/// Distinct genre names from VOD entries in the active playlist.
final vodGroupsProvider = Provider.autoDispose<List<String>>((ref) {
  final channelsAsync = ref.watch(vodChannelsStreamProvider);
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

/// VOD movies after applying the active genre filter.
final filteredVodChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels = ref.watch(vodChannelsStreamProvider).valueOrNull ?? const [];
  final groupFilter = ref.watch(selectedVodGroupFilterProvider);
  final hidden = ref.watch(hiddenGroupsProvider).valueOrNull ?? const {};
  final search = ref.watch(debouncedGlobalSearchQueryProvider);
  return filterChannels(
    channels: channels,
    groupFilter: groupFilter,
    hiddenGroups: hidden,
    searchQuery: search,
  );
});

/// Public alias used by the VOD grid UI.
final vodChannelsProvider = filteredVodChannelsProvider;

/// Applies [groupFilter] to [channels] — extracted for unit tests.
List<Channel> filterVodChannelsByGroup(
  List<Channel> channels,
  String groupFilter,
) => filterChannelsByGroup(channels, groupFilter);
