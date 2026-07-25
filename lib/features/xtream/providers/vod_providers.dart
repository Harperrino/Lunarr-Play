import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
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
      ref.listen<PlaylistCatalogScope?>(playlistCatalogScopeProvider, (
        previous,
        next,
      ) {
        if (previous != next) {
          ref.read(selectedVodGroupFilterProvider.notifier).state =
              kAllGroupsFilter;
        }
      });
      return kAllGroupsFilter;
    });

/// Distinct genre names from VOD entries in the active playlist.
final vodGroupsProvider = Provider.autoDispose<List<String>>((ref) {
  return <String>{
    for (final entry in ref.watch(vodCategoryEntriesProvider)) entry.groupName,
  }.toList();
});

final vodCategoryEntriesProvider =
    Provider.autoDispose<List<PlaylistCatalogCategory>>((ref) {
      final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
      return ref.watch(
        playlistCatalogCategoryProvider(
          PlaylistCatalogQuery(
            scope: scope,
            mediaType: PlaylistCatalogMediaType.vod,
          ),
        ),
      );
    });

/// VOD movies after applying the active genre filter.
final filteredVodChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels = ref.watch(vodChannelsStreamProvider).valueOrNull ?? const [];
  final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
  final ids = ref.watch(playlistCatalogPlaylistIdsProvider(scope));
  final hiddenByPlaylist = <int, Set<String>>{
    for (final playlistId in ids)
      playlistId:
          ref.watch(hiddenGroupsForPlaylistProvider(playlistId)).valueOrNull ??
          const <String>{},
  };
  final groupFilter = ref.watch(selectedVodGroupFilterProvider);
  final search = ref.watch(debouncedGlobalSearchQueryProvider);
  return filterPlaylistCatalogChannels(
    channels: channels,
    groupFilter: groupFilter,
    hiddenGroupsByPlaylist: hiddenByPlaylist,
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
