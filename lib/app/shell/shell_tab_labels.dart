import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tab_labels.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';

export 'package:m3uxtream_player/shared/navigation/shell_tab_labels.dart';

/// Header copy for sidebar tabs (shared by live and standard shell).
String shellHeaderTitle(
  int activeIndex, {
  required bool debugModeEnabled,
  required AppLocalizations l10n,
}) {
  activeIndex = shellNavigationIndexFor(activeIndex);
  final tab =
      shellTabForIndex(activeIndex, debugModeEnabled: debugModeEnabled) ??
      shellTabForIndex(
        shellFallbackTabIndex(),
        debugModeEnabled: debugModeEnabled,
      );

  return tab == null ? l10n.shellFallbackTitle : shellTabTitle(tab, l10n);
}

String shellHeaderSubtitle(
  int activeIndex, {
  required bool debugModeEnabled,
  required AppLocalizations l10n,
}) {
  activeIndex = shellNavigationIndexFor(activeIndex);
  final tab =
      shellTabForIndex(activeIndex, debugModeEnabled: debugModeEnabled) ??
      shellTabForIndex(
        shellFallbackTabIndex(),
        debugModeEnabled: debugModeEnabled,
      );

  return tab == null ? l10n.shellFallbackSubtitle : shellTabSubtitle(tab, l10n);
}
