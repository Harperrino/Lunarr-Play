import 'package:m3uxtream_player/app/shell/shell_tabs.dart';

/// Header copy for sidebar tabs (shared by live and standard shell).
String shellHeaderTitle(int activeIndex, {required bool debugModeEnabled}) {
  activeIndex = shellNavigationIndexFor(activeIndex);
  final tab =
      shellTabForIndex(activeIndex, debugModeEnabled: debugModeEnabled) ??
      shellTabForIndex(
        shellFallbackTabIndex(),
        debugModeEnabled: debugModeEnabled,
      );

  return tab?.title ?? 'Neural Control Center';
}

String shellHeaderSubtitle(int activeIndex, {required bool debugModeEnabled}) {
  activeIndex = shellNavigationIndexFor(activeIndex);
  final tab =
      shellTabForIndex(activeIndex, debugModeEnabled: debugModeEnabled) ??
      shellTabForIndex(
        shellFallbackTabIndex(),
        debugModeEnabled: debugModeEnabled,
      );

  return tab?.subtitle ?? 'Material 3 media workspace (Drift & Riverpod)';
}
