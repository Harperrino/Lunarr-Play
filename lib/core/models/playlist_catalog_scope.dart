import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/core/services/channel_sorting.dart';

/// Scope used by catalogues only. Playback and detail selection continue to
/// use [selectedPlaylistIdProvider] and therefore never inherit the All scope.
class PlaylistCatalogScope {
  const PlaylistCatalogScope.single(this.playlistId) : isAllActive = false;

  const PlaylistCatalogScope.allActive()
    : playlistId = null,
      isAllActive = true;

  final int? playlistId;
  final bool isAllActive;

  @override
  bool operator ==(Object other) =>
      other is PlaylistCatalogScope &&
      other.playlistId == playlistId &&
      other.isAllActive == isAllActive;

  @override
  int get hashCode => Object.hash(playlistId, isAllActive);

  @override
  String toString() => isAllActive
      ? 'PlaylistCatalogScope.allActive'
      : 'PlaylistCatalogScope.single($playlistId)';
}

enum PlaylistCatalogMediaType {
  live,
  vod,
  series;

  String get databaseValue => name;
}

/// Family key for a stream. Equality is intentionally value based so rapid
/// scope changes reuse a warm entry instead of creating duplicate streams.
class PlaylistCatalogQuery {
  const PlaylistCatalogQuery({required this.scope, required this.mediaType});

  final PlaylistCatalogScope scope;
  final PlaylistCatalogMediaType mediaType;

  @override
  bool operator ==(Object other) =>
      other is PlaylistCatalogQuery &&
      other.scope == scope &&
      other.mediaType == mediaType;

  @override
  int get hashCode => Object.hash(scope, mediaType);
}

/// A category retains its playlist identity in All scope. This prevents two
/// providers using the same visible group name from collapsing into one row.
class PlaylistCatalogCategory {
  const PlaylistCatalogCategory({
    required this.groupName,
    required this.playlistId,
    required this.playlistName,
    required this.isPinned,
    required this.channelCount,
    required this.showPlaylistName,
  });

  final String groupName;
  final int playlistId;
  final String playlistName;
  final bool isPinned;
  final int channelCount;
  final bool showPlaylistName;

  String get filterKey => playlistCatalogCategoryKey(playlistId, groupName);
  String get secondaryLabel => showPlaylistName ? playlistName : '';
}

String playlistCatalogCategoryKey(int playlistId, String groupName) =>
    '$playlistId\u0000$groupName';

/// Filters a catalog while respecting per-playlist visibility and category
/// identity. A plain group name remains accepted for single-playlist callers.
///
/// In the unfiltered default case (category "Alle", empty search, no hidden
/// categories) the incoming list instance is passed through unchanged —
/// no full copy, no extra pass over the catalogue.
List<Channel> filterPlaylistCatalogChannels({
  required Iterable<Channel> channels,
  required String groupFilter,
  required String searchQuery,
  required Map<int, Set<String>> hiddenGroupsByPlaylist,
}) {
  final normalizedSearch = searchQuery.trim().toLowerCase();
  final filterByGroup = groupFilter != kAllGroupsFilter;

  final hasHiddenGroups = hiddenGroupsByPlaylist.values.any(
    (groups) => groups.isNotEmpty,
  );
  if (!filterByGroup && normalizedSearch.isEmpty && !hasHiddenGroups) {
    return channels is List<Channel>
        ? channels
        : channels.toList(growable: false);
  }

  return channels
      .where((channel) {
        final group = normalizeGroupName(channel.groupName);
        final hidden =
            hiddenGroupsByPlaylist[channel.playlistId] ?? const <String>{};
        if (hidden.contains(group)) return false;

        if (filterByGroup &&
            groupFilter != group &&
            groupFilter !=
                playlistCatalogCategoryKey(channel.playlistId, group)) {
          return false;
        }

        if (normalizedSearch.isEmpty) return true;
        return channel.name.toLowerCase().contains(normalizedSearch) ||
            group.toLowerCase().contains(normalizedSearch);
      })
      .toList(growable: false);
}

List<PlaylistCatalogCategory> buildPlaylistCatalogCategories({
  required Iterable<Channel> channels,
  required PlaylistCatalogScope scope,
  required Map<int, String> playlistNamesById,
  required Map<int, Set<String>> hiddenGroupsByPlaylist,
  required Map<int, List<String>> pinnedGroupsByPlaylist,
}) {
  final counts = <(int, String), int>{};
  for (final channel in channels) {
    final group = normalizeGroupName(channel.groupName);
    final hidden =
        hiddenGroupsByPlaylist[channel.playlistId] ?? const <String>{};
    if (!hidden.contains(group)) {
      final key = (channel.playlistId, group);
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }

  final categories = [
    for (final entry in counts.entries)
      PlaylistCatalogCategory(
        groupName: entry.key.$2,
        playlistId: entry.key.$1,
        playlistName: playlistNamesById[entry.key.$1] ?? 'Playlist',
        isPinned: (pinnedGroupsByPlaylist[entry.key.$1] ?? const <String>[])
            .contains(entry.key.$2),
        channelCount: entry.value,
        showPlaylistName: scope.isAllActive,
      ),
  ];

  final playlistOrder = <int, int>{};
  var order = 0;
  for (final playlistId in playlistNamesById.keys) {
    playlistOrder[playlistId] = order++;
  }

  categories.sort((a, b) {
    final aPinned = a.isPinned ? 0 : 1;
    final bPinned = b.isPinned ? 0 : 1;
    if (aPinned != bPinned) return aPinned.compareTo(bPinned);

    if (scope.isAllActive) {
      final playlistCompare = (playlistOrder[a.playlistId] ?? 0).compareTo(
        playlistOrder[b.playlistId] ?? 0,
      );
      if (playlistCompare != 0) return playlistCompare;
    }

    final nameCompare = a.groupName.toLowerCase().compareTo(
      b.groupName.toLowerCase(),
    );
    if (nameCompare != 0) return nameCompare;
    return a.playlistName.toLowerCase().compareTo(b.playlistName.toLowerCase());
  });
  return categories;
}

/// Applies the single-playlist sort contract and the All-scope provider-order
/// contract without doing extra parsing inside the comparator.
List<Channel> sortPlaylistCatalogChannels({
  required Iterable<Channel> channels,
  required ChannelSortMode mode,
  required List<int> playlistOrder,
}) {
  final values = channels.toList(growable: true);
  if (mode != ChannelSortMode.providerDefault || playlistOrder.length <= 1) {
    return sortChannels(values, mode);
  }

  final orderByPlaylist = <int, int>{
    for (var index = 0; index < playlistOrder.length; index++)
      playlistOrder[index]: index,
  };
  values.sort((a, b) {
    final playlistCompare = (orderByPlaylist[a.playlistId] ?? 1 << 30)
        .compareTo(orderByPlaylist[b.playlistId] ?? 1 << 30);
    if (playlistCompare != 0) return playlistCompare;

    final providerCompare = effectiveChannelProviderOrder(
      a,
    ).compareTo(effectiveChannelProviderOrder(b));
    if (providerCompare != 0) return providerCompare;
    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) return nameCompare;
    return a.id.compareTo(b.id);
  });
  return values;
}
