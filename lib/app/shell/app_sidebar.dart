import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/shell_sidebar.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';

/// Primary navigation rail for non-live tabs.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.activeIndex,
    required this.debugModeEnabled,
    this.hiddenTabKinds = const {},
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onTap,
  });

  final int activeIndex;
  final bool debugModeEnabled;
  final Set<ShellTabKind> hiddenTabKinds;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ShellSidebar(
      activeIndex: activeIndex,
      debugModeEnabled: debugModeEnabled,
      hiddenTabKinds: hiddenTabKinds,
      isExpanded: isExpanded,
      onToggleExpanded: onToggleExpanded,
      onTap: onTap,
    );
  }
}
