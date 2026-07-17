import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
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
    final selected = ref.watch(selectedGroupFilterProvider);
    final pinnedGroups =
        ref.watch(pinnedGroupsProvider).valueOrNull ?? const <String>[];

    return CategorySidebar(
      groups: groups,
      selectedGroup: selected,
      onSelected: (group) =>
          ref.read(selectedGroupFilterProvider.notifier).state = group,
      pinnedGroups: pinnedGroups,
      width: width,
      headerActions: headerActions,
    );
  }
}
