import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/core/constants/app_identity.dart';
import 'package:m3uxtream_player/shared/widgets/app_brand_mark.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface_state_layer.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';

/// Shared Material 3 navigation rail used by the live and non-live shells.
class ShellSidebar extends StatelessWidget {
  const ShellSidebar({
    super.key,
    required this.activeIndex,
    required this.onTap,
    required this.onToggleExpanded,
    required this.debugModeEnabled,
    required this.isExpanded,
  });

  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onToggleExpanded;
  final bool debugModeEnabled;
  final bool isExpanded;

  static const double _expandedContentMinWidth = 160;

  @override
  Widget build(BuildContext context) {
    final tabs = shellVisibleTabs(debugModeEnabled: debugModeEnabled);
    final navigationIndex = shellNavigationIndexFor(activeIndex);
    final effectiveActiveIndex =
        shellTabVisible(navigationIndex, debugModeEnabled: debugModeEnabled)
        ? navigationIndex
        : shellFallbackTabIndex();
    final width = shellSidebarWidth(isExpanded);
    final colorScheme = Theme.of(context).colorScheme;
    final settingsTab = tabs.firstWhere(
      (tab) => tab.index == shellSettingsTabIndex,
    );
    final primaryTabs = tabs
        .where((tab) => tab.index != shellSettingsTabIndex)
        .toList(growable: false);

    return AnimatedContainer(
      duration: shellSidebarTransitionDuration,
      curve: Curves.easeOutCubic,
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showExpandedContent =
                  isExpanded &&
                  constraints.maxWidth >= _expandedContentMinWidth;

              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SidebarHeader(
                      isExpanded: showExpandedContent,
                      onToggleExpanded: onToggleExpanded,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Column(
                        children: [
                          for (final tab in primaryTabs) ...[
                            _SidebarItem(
                              tab: tab,
                              isExpanded: showExpandedContent,
                              isActive: effectiveActiveIndex == tab.index,
                              onTap: onTap,
                            ),
                            const SizedBox(height: 4),
                          ],
                          const Spacer(),
                          _SidebarItem(
                            tab: settingsTab,
                            isExpanded: showExpandedContent,
                            isActive: effectiveActiveIndex == settingsTab.index,
                            onTap: onTap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SidebarHeader extends StatefulWidget {
  const _SidebarHeader({
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  static const double _toggleCorridorWidth = 72;

  final FocusNode _toggleFocusNode = FocusNode(
    debugLabel: 'ShellSidebarToggle',
  );

  @override
  void didUpdateWidget(_SidebarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded && !widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _toggleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isExpanded) {
      return Center(
        child: M3PaneToggleButton(
          paneLabel: 'Sidebar',
          expanded: false,
          onPressed: widget.onToggleExpanded,
          focusNode: _toggleFocusNode,
          collapsedTooltip: 'Expand sidebar',
          focusOutlineKey: const ValueKey('shell-sidebar-focus-ring'),
          focusOutlineStyle: AppFocusOutlineStyle.box,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Positioned.fill(
            right: _toggleCorridorWidth,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Semantics(
                  header: true,
                  label: AppIdentity.displayName,
                  child: ExcludeSemantics(
                    child: Row(
                      key: const ValueKey('shell-sidebar-brand'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppBrandMark(
                          key: ValueKey('shell-sidebar-brand-mark'),
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppIdentity.displayName,
                          key: const ValueKey('shell-sidebar-brand-wordmark'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: M3PaneToggleButton(
              paneLabel: 'Sidebar',
              expanded: true,
              onPressed: widget.onToggleExpanded,
              focusNode: _toggleFocusNode,
              expandedTooltip: 'Collapse sidebar',
              focusOutlineKey: const ValueKey('shell-sidebar-focus-ring'),
              focusOutlineStyle: AppFocusOutlineStyle.box,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.tab,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
  });

  final ShellTabSpec tab;
  final bool isExpanded;
  final bool isActive;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return M3NavigationItem(
      key: ValueKey('shell-sidebar-item-${tab.index}'),
      label: tab.title,
      tooltip: tab.title,
      icon: tab.icon,
      selected: isActive,
      onPressed: () => onTap(tab.index),
      height: shellSidebarNavigationRowHeight,
      visualRole: M3NavigationItemVisualRole.navigationRail,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shellSidebarSelectedRadius),
      ),
      expanded: isExpanded,
      focusOutlineKey: const ValueKey('shell-sidebar-focus-ring'),
    );
  }
}
