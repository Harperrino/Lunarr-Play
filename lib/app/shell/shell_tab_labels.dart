import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';

String shellTabTitle(ShellTabSpec tab, AppLocalizations l10n) =>
    switch (tab.kind) {
      ShellTabKind.live => l10n.shellTabLiveTitle,
      ShellTabKind.mediaLibrary => l10n.shellTabMediaLibraryTitle,
      ShellTabKind.favorites => l10n.shellTabFavoritesTitle,
      ShellTabKind.playlists => l10n.shellTabPlaylistsTitle,
      ShellTabKind.epg => l10n.shellTabEpgTitle,
      ShellTabKind.vod => l10n.shellTabVodTitle,
      ShellTabKind.series => l10n.shellTabSeriesTitle,
      ShellTabKind.diagnostics => l10n.shellTabDiagnosticsTitle,
      ShellTabKind.settings => l10n.shellTabSettingsTitle,
    };

String shellTabSubtitle(ShellTabSpec tab, AppLocalizations l10n) =>
    switch (tab.kind) {
      ShellTabKind.live => l10n.shellTabLiveSubtitle,
      ShellTabKind.mediaLibrary => l10n.shellTabMediaLibrarySubtitle,
      ShellTabKind.favorites => l10n.shellTabFavoritesSubtitle,
      ShellTabKind.playlists => l10n.shellTabPlaylistsSubtitle,
      ShellTabKind.epg => l10n.shellTabEpgSubtitle,
      ShellTabKind.vod => l10n.shellTabVodSubtitle,
      ShellTabKind.series => l10n.shellTabSeriesSubtitle,
      ShellTabKind.diagnostics => l10n.shellTabDiagnosticsSubtitle,
      ShellTabKind.settings => l10n.shellTabSettingsSubtitle,
    };

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
