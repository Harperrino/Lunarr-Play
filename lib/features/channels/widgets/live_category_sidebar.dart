import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';
import 'package:m3uxtream_player/core/services/detached_future.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/shared/widgets/category_sidebar.dart';

/// Live-tab category panel — reads channel groups from Riverpod.
class LiveCategorySidebar extends ConsumerWidget {
  const LiveCategorySidebar({
    super.key,
    this.width = LiveLayoutMetrics.categoryPanelWidth,
    this.headerActions,
  });

  final double width;
  final Widget? headerActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(channelGroupsProvider);
    final typedEntries = ref.watch(liveCategoryEntriesProvider);
    // Keep the compatibility group projection usable while a typed catalog
    // is still empty (and for isolated consumers that only provide groups).
    final categoryEntries = typedEntries.isEmpty ? null : typedEntries;
    final selected = ref.watch(selectedGroupFilterProvider);
    final pinnedGroups =
        ref.watch(pinnedGroupsProvider).valueOrNull ?? const <String>[];
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);

    return CategorySidebar(
      groups: groups,
      categoryEntries: categoryEntries,
      selectedGroup: selected,
      onSelected: (group) =>
          ref.read(selectedGroupFilterProvider.notifier).state = group,
      pinnedGroups: pinnedGroups,
      onPinChanged: selectedPlaylistId == null
          ? null
          : (groupName, pinned) {
              unawaited(
                ref
                    .read(pinnedGroupsProvider.notifier)
                    .toggleGroup(selectedPlaylistId, groupName, pinned),
              );
            },
      onCategoryPinChanged: (category, pinned) {
        runDetached(() async {
          final repository = ref.read(appStateRepositoryProvider);
          final current = await repository.getPinnedGroups(category.playlistId);
          if (pinned) {
            current.remove(category.groupName);
            current.add(category.groupName);
          } else {
            current.remove(category.groupName);
          }
          await repository.setPinnedGroups(category.playlistId, current);
          ref.invalidate(pinnedGroupsForPlaylistProvider(category.playlistId));
          if (ref.read(selectedPlaylistIdProvider) == category.playlistId) {
            ref.invalidate(pinnedGroupsProvider);
          }
        }, label: 'pin category');
      },
      width: width,
      headerActions: headerActions,
    );
  }
}
