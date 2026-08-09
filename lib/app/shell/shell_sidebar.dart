import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/shell_tab_labels.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';
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
    this.hiddenTabKinds = const {},
    required this.isExpanded,
  });

  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onToggleExpanded;
  final bool debugModeEnabled;
  final Set<ShellTabKind> hiddenTabKinds;
  final bool isExpanded;

  static const double _expandedContentMinWidth = 160;

  @override
  Widget build(BuildContext context) {
    final tabs = shellVisibleTabs(
      debugModeEnabled: debugModeEnabled,
      hiddenKinds: hiddenTabKinds,
    );
    final navigationIndex = shellNavigationIndexFor(activeIndex);
    final effectiveActiveIndex =
        shellTabVisible(
          navigationIndex,
          debugModeEnabled: debugModeEnabled,
          hiddenKinds: hiddenTabKinds,
        )
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
          paneLabel: context.l10n.shellSidebarLabel,
          expanded: false,
          onPressed: widget.onToggleExpanded,
          focusNode: _toggleFocusNode,
          collapsedTooltip: context.l10n.paneExpandAction(
            context.l10n.shellSidebarLabel,
          ),
          focusOutlineKey: const ValueKey('shell-sidebar-focus-ring'),
          focusOutlineStyle: AppFocusOutlineStyle.box,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.centerRight,
        child: M3PaneToggleButton(
          paneLabel: context.l10n.shellSidebarLabel,
          expanded: true,
          onPressed: widget.onToggleExpanded,
          focusNode: _toggleFocusNode,
          expandedTooltip: context.l10n.paneCollapseAction(
            context.l10n.shellSidebarLabel,
          ),
          focusOutlineKey: const ValueKey('shell-sidebar-focus-ring'),
          focusOutlineStyle: AppFocusOutlineStyle.box,
        ),
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
    final title = shellTabTitle(tab, context.l10n);
    return M3NavigationItem(
      key: ValueKey('shell-sidebar-item-${tab.index}'),
      label: title,
      tooltip: title,
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
