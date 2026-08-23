import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/constants/filter_constants.dart';
import 'package:m3uxtream_player/shared/layout/live_layout_geometry.dart';
import 'package:m3uxtream_player/core/models/playlist_catalog_scope.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_scrollbar.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';

/// Vertical, scrollable category list — placed to the right of the player or content grid.
class CategorySidebar extends StatefulWidget {
  const CategorySidebar({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
    this.pinnedGroups = const <String>[],
    this.showPinIndicators = true,
    this.onPinChanged,
    this.title = 'Categories',
    this.width = LiveLayoutMetrics.categoryPanelWidth,
    this.headerActions,
    this.categoryEntries,
    this.onCategoryPinChanged,
  });

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onSelected;
  final List<String> pinnedGroups;
  final bool showPinIndicators;
  final void Function(String groupName, bool pinned)? onPinChanged;
  final String title;
  final double width;
  final Widget? headerActions;
  final List<PlaylistCatalogCategory>? categoryEntries;
  final void Function(PlaylistCatalogCategory category, bool pinned)?
  onCategoryPinChanged;

  @override
  State<CategorySidebar> createState() => _CategorySidebarState();
}

class _CategorySidebarState extends State<CategorySidebar> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty &&
        (widget.categoryEntries == null || widget.categoryEntries!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final entries = widget.categoryEntries;
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: widget.width,
      child: AppSurface(
        level: AppSurfaceLevel.low,
        elevation: AppElevation.level1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                M3LeadingSlot(
                  icon: Icons.layers_rounded,
                  glyphSize: 14,
                  foregroundColor: colors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.headerActions != null) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: widget.headerActions!,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: AppScrollbar(
                controller: _scrollController,
                axis: Axis.vertical,
                padding: const EdgeInsets.only(right: 8),
                child: ListView.separated(
                  controller: _scrollController,
                  primary: false,
                  itemCount: (entries?.length ?? widget.groups.length) + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final category = entries == null || index == 0
                        ? null
                        : entries[index - 1];
                    final group =
                        category?.filterKey ??
                        (index == 0
                            ? kAllGroupsFilter
                            : widget.groups[index - 1]);
                    final label =
                        category?.groupName ??
                        (group == kAllGroupsFilter ? 'All' : group);
                    final isSelected = widget.selectedGroup == group;
                    final isPinned =
                        category?.isPinned ??
                        (widget.showPinIndicators &&
                            group != kAllGroupsFilter &&
                            widget.pinnedGroups.contains(group));
                    final accent = group == kAllGroupsFilter
                        ? colors.primary
                        : GroupAccent.forGroup(group);

                    return _CategoryTile(
                      groupName: group,
                      label: label,
                      isAll: group == kAllGroupsFilter,
                      isSelected: isSelected,
                      isPinned: isPinned,
                      supportingText: category?.secondaryLabel,
                      showPinIndicator: widget.showPinIndicators,
                      accent: accent,
                      onTap: () => widget.onSelected(group),
                      onPinChanged: group == kAllGroupsFilter
                          ? null
                          : category != null &&
                                widget.onCategoryPinChanged != null
                          ? (groupName, pinned) =>
                                widget.onCategoryPinChanged!(category, pinned)
                          : widget.onPinChanged,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.groupName,
    required this.label,
    required this.isAll,
    required this.isSelected,
    required this.isPinned,
    required this.showPinIndicator,
    required this.accent,
    required this.onTap,
    this.onPinChanged,
    this.supportingText,
  });

  final String groupName;
  final String label;
  final bool isAll;
  final bool isSelected;
  final bool isPinned;
  final bool showPinIndicator;
  final String? supportingText;
  final Color accent;
  final VoidCallback onTap;
  final void Function(String groupName, bool pinned)? onPinChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canPin = onPinChanged != null;
    final navigationItem = M3NavigationItem(
      label: label,
      supportingText: supportingText,
      leading: _CategoryLeadingIcon(
        isAll: isAll,
        selected: isSelected,
        colorScheme: colorScheme,
      ),
      trailing: canPin
          ? M3ActionSlot(
              icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              tooltip: isPinned ? 'Unpin category' : 'Pin category',
              semanticLabel: isPinned
                  ? 'Unpin category $label'
                  : 'Pin category $label',
              toggled: isPinned,
              selected: isPinned,
              foregroundColor: isSelected
                  ? colorScheme.onSecondaryContainer
                  : accent.withValues(alpha: 0.92),
              backgroundColor: Colors.transparent,
              onPressed: () => onPinChanged!(groupName, !isPinned),
            )
          : showPinIndicator && isPinned
          ? Icon(
              Icons.push_pin_rounded,
              size: 15,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : accent.withValues(alpha: 0.92),
            )
          : null,
      trailingInteractive: canPin,
      selected: isSelected,
      onPressed: onTap,
      visualRole: M3NavigationItemVisualRole.categoryNavigation,
      height: 52,
      focusOutlineKey: const ValueKey('category-sidebar-focus-ring'),
      transitionDuration: AppMotion.of(context).content,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    );

    if (!canPin) return navigationItem;

    return MenuAnchor(
      consumeOutsideTap: false,
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        MenuItemButton(
          key: ValueKey('category-pin-context-menu-$groupName'),
          leadingIcon: Icon(
            isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          ),
          onPressed: () => onPinChanged!(groupName, !isPinned),
          child: Text(isPinned ? 'Unpin category' : 'Pin category'),
        ),
      ],
      builder: (context, controller, child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: (details) {
          controller.open(position: details.localPosition);
        },
        child: child!,
      ),
      child: navigationItem,
    );
  }
}

class _CategoryLeadingIcon extends StatelessWidget {
  const _CategoryLeadingIcon({
    required this.isAll,
    required this.selected,
    required this.colorScheme,
  });

  final bool isAll;
  final bool selected;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final icon = isAll ? Icons.apps_rounded : Icons.folder_copy_rounded;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Icon(icon, size: 20, color: foreground);
  }
}
