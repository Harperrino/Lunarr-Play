import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/app_sidebar.dart';
import 'package:m3uxtream_player/app/shell/non_live_tab_body.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/app/shell/shell_layout.dart';
import 'package:m3uxtream_player/app/shell/shell_tab_labels.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/shared/theme/app_spacing.dart';

/// Layout for sidebar tabs 1â€“6 (playlists, EPG, VOD, series, diagnostics, settings).
class StandardAppShell extends StatelessWidget {
  const StandardAppShell({
    super.key,
    required this.activeIndex,
    required this.debugModeEnabled,
    required this.sidebarExpanded,
    required this.onSidebarToggle,
    required this.onSidebarTap,
  });

  final int activeIndex;
  final bool debugModeEnabled;
  final bool sidebarExpanded;
  final VoidCallback onSidebarToggle;
  final ValueChanged<int> onSidebarTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desiredSidebarWidth = shellSidebarWidth(sidebarExpanded);
        final sidebarMaxWidth = constraints.maxWidth < desiredSidebarWidth
            ? constraints.maxWidth
            : desiredSidebarWidth;

        return Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: sidebarMaxWidth),
              child: AppSidebar(
                activeIndex: activeIndex,
                debugModeEnabled: debugModeEnabled,
                isExpanded: sidebarExpanded,
                onToggleExpanded: onSidebarToggle,
                onTap: onSidebarTap,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final spacing =
                      Theme.of(context).extension<AppSpacing>() ??
                      AppSpacing.standard;
                  final gutter = shellContentGutterFor(
                    constraints.maxWidth,
                    spacing,
                  );

                  return Padding(
                    padding: EdgeInsets.all(gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShellCommandArea(
                          title: shellHeaderTitle(
                            activeIndex,
                            debugModeEnabled: debugModeEnabled,
                          ),
                          supportingText: shellHeaderSubtitle(
                            activeIndex,
                            debugModeEnabled: debugModeEnabled,
                          ),
                        ),
                        SizedBox(height: spacing.xl),
                        Expanded(
                          child: NonLiveTabBody(
                            activeIndex: activeIndex,
                            debugModeEnabled: debugModeEnabled,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
