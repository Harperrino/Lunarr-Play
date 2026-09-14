import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';

enum PlaylistContentFilter {
  all,
  live,
  vod,
  series;

  String get label => switch (this) {
    PlaylistContentFilter.all => 'All',
    PlaylistContentFilter.live => 'Live',
    PlaylistContentFilter.vod => 'VOD',
    PlaylistContentFilter.series => 'Series',
  };

  String get contentType => switch (this) {
    PlaylistContentFilter.all => '',
    PlaylistContentFilter.live => 'live',
    PlaylistContentFilter.vod => 'vod',
    PlaylistContentFilter.series => 'series',
  };

  String get emptyMessage => switch (this) {
    PlaylistContentFilter.all => 'No categories found in this playlist.',
    PlaylistContentFilter.live => 'No live categories found in this playlist.',
    PlaylistContentFilter.vod => 'No VOD categories found in this playlist.',
    PlaylistContentFilter.series =>
      'No series categories found in this playlist.',
  };

  String get bulkLabelSuffix => switch (this) {
    PlaylistContentFilter.all => 'all categories',
    PlaylistContentFilter.live => 'live categories',
    PlaylistContentFilter.vod => 'VOD categories',
    PlaylistContentFilter.series => 'series categories',
  };
}

final selectedPlaylistContentFilterProvider =
    StateProvider<PlaylistContentFilter>((ref) => PlaylistContentFilter.all);

class PlaylistHubCategoryViewData {
  const PlaylistHubCategoryViewData({
    required this.allGroups,
    required this.visibleGroups,
    required this.hiddenGroups,
    required this.pinnedGroups,
    required this.matchingChannelCount,
    required this.pinnedVisibleCount,
    required this.pinnedHiddenCount,
  });

  final List<String> allGroups;
  final List<String> visibleGroups;
  final List<String> hiddenGroups;
  final Set<String> pinnedGroups;
  final int matchingChannelCount;
  final int pinnedVisibleCount;
  final int pinnedHiddenCount;
}

/// Derives the category panel state without materializing a filtered channel
/// catalogue. Category membership and content-type filtering share one pass.
PlaylistHubCategoryViewData buildPlaylistHubCategoryViewData({
  required List<Channel> channels,
  required PlaylistContentFilter contentFilter,
  required Set<String> hiddenGroups,
  required List<String> pinnedGroups,
}) {
  final requiredType = contentFilter.contentType;
  final groups = <String>{};
  var matchingChannelCount = 0;

  for (final channel in channels) {
    if (requiredType.isNotEmpty && channel.channelType != requiredType) {
      continue;
    }
    matchingChannelCount++;
    groups.add(normalizeGroupName(channel.groupName));
  }

  final allGroups = groups.toList()..sort();
  final visible = <String>[];
  final hidden = <String>[];
  for (final group in allGroups) {
    (hiddenGroups.contains(group) ? hidden : visible).add(group);
  }

  final pinned = pinnedGroups.toSet();
  final prioritizedVisible = prioritizePinnedGroups(visible, pinnedGroups);

  return PlaylistHubCategoryViewData(
    allGroups: allGroups,
    visibleGroups: prioritizedVisible,
    hiddenGroups: hidden,
    pinnedGroups: pinned,
    matchingChannelCount: matchingChannelCount,
    pinnedVisibleCount: prioritizedVisible.where(pinned.contains).length,
    pinnedHiddenCount: hidden.where(pinned.contains).length,
  );
}
