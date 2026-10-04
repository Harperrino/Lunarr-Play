import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

/// Null follows the current catalogue scope. Explicit selections belong only
/// to the guide; changing them never changes playback or the Live sidebar.
final epgPlaylistFilterProvider = StateProvider<Set<int>?>((ref) => null);
final epgCategoryFilterProvider = StateProvider<Set<String>?>((ref) => null);

final epgFilterPlaylistIdsProvider = Provider.autoDispose<List<int>>((ref) {
  final selected = ref.watch(epgPlaylistFilterProvider);
  if (selected == null) {
    final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
    return ref.watch(playlistCatalogPlaylistIdsProvider(scope));
  }
  final playlists = ref.watch(playlistsStreamProvider).valueOrNull ?? const [];
  return [
    for (final playlist in playlists)
      if (selected.contains(playlist.id)) playlist.id,
  ];
});

/// Reuses canonical per-playlist streams rather than querying every category.
final epgGuideChannelsProvider =
    Provider.autoDispose<AsyncValue<List<Channel>>>((ref) {
      if (ref.watch(epgPlaylistFilterProvider) == null) {
        return ref.watch(liveChannelsStreamProvider);
      }
      final playlists = ref.watch(playlistsStreamProvider);
      if (playlists.hasError) {
        return AsyncError(playlists.error!, playlists.stackTrace!);
      }
      if (!playlists.hasValue) {
        return const AsyncLoading();
      }
      final channels = <Channel>[];
      var loading = false;
      for (final id in ref.watch(epgFilterPlaylistIdsProvider)) {
        final value = ref.watch(
          playlistCatalogStreamProvider(
            PlaylistCatalogQuery(
              scope: PlaylistCatalogScope.single(id),
              mediaType: PlaylistCatalogMediaType.live,
            ),
          ),
        );
        if (value.hasError && !value.hasValue) {
          return AsyncError(value.error!, value.stackTrace!);
        }
        loading |= value.isLoading;
        channels.addAll(value.valueOrNull ?? const []);
      }
      final data = AsyncData<List<Channel>>(channels);
      return loading
          ? const AsyncLoading<List<Channel>>().copyWithPrevious(data)
          : data;
    });

final epgAvailableChannelsProvider = Provider.autoDispose<List<Channel>>((ref) {
  final channels =
      ref.watch(epgGuideChannelsProvider).valueOrNull ?? const <Channel>[];
  final hidden = {
    for (final id in ref.watch(epgFilterPlaylistIdsProvider))
      id:
          ref.watch(hiddenGroupsForPlaylistProvider(id)).valueOrNull ??
          const <String>{},
  };
  return channels
      .where(
        (channel) =>
            !(hidden[channel.playlistId]?.contains(
                  normalizeGroupName(channel.groupName),
                ) ??
                false),
      )
      .toList(growable: false);
});

final epgFilterCategoriesProvider =
    Provider.autoDispose<List<PlaylistCatalogCategory>>((ref) {
      return buildPlaylistCatalogCategories(
        channels: ref.watch(epgAvailableChannelsProvider),
        scope: const PlaylistCatalogScope.allActive(),
        playlistNamesById: ref.watch(playlistNamesByIdProvider),
        hiddenGroupsByPlaylist: const {},
        pinnedGroupsByPlaylist: const {},
      );
    });

List<Channel> filterEpgGuideChannels({
  required List<Channel> channels,
  required Set<String>? categories,
  required String search,
}) {
  final query = search.trim().toLowerCase();
  return channels
      .where(
        (channel) =>
            (categories == null ||
                categories.contains(
                  playlistCatalogCategoryKey(
                    channel.playlistId,
                    normalizeGroupName(channel.groupName),
                  ),
                )) &&
            (query.isEmpty || channel.name.toLowerCase().contains(query)),
      )
      .toList();
}

final epgFilteredChannelsProvider = Provider.autoDispose<List<Channel>>(
  (ref) => filterEpgGuideChannels(
    channels: ref.watch(epgAvailableChannelsProvider),
    categories: ref.watch(epgCategoryFilterProvider),
    search: ref.watch(globalSearchQueryProvider),
  ),
);
