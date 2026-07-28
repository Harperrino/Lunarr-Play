import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/layout/live_composition_geometry.dart';

const shellLiveTabIndex = 0;
const shellPlaylistsTabIndex = 1;
const shellEpgTabIndex = 2;
const shellVodTabIndex = 3;
const shellSeriesTabIndex = 4;
const shellSettingsTabIndex = 5;
const shellDiagnosticsTabIndex = 6;
const shellFavoritesTabIndex = 7;
const shellMediaLibraryTabIndex = 8;

/// Central layout tokens shared by every windowed shell.
const double shellSidebarCollapsedWidth =
    LiveCompositionMetrics.shellSidebarCollapsedWidth;
const double shellSidebarExpandedWidth =
    LiveCompositionMetrics.shellSidebarExpandedWidth;
const double shellSidebarNavigationRowHeight = 48.0;
const double shellSidebarSelectedRadius = 24.0;
const Duration shellSidebarTransitionDuration = Duration(milliseconds: 280);

class ShellTabSpec {
  const ShellTabSpec({
    required this.index,
    required this.icon,
    required this.kind,
    this.debugOnly = false,
    this.visibleInNavigation = true,
  });

  final int index;
  final IconData icon;
  final ShellTabKind kind;
  final bool debugOnly;
  final bool visibleInNavigation;
}

enum ShellTabKind {
  live,
  mediaLibrary,
  favorites,
  playlists,
  epg,
  vod,
  series,
  diagnostics,
  settings,
}

const List<ShellTabSpec> shellTabSpecs = [
  ShellTabSpec(
    index: shellLiveTabIndex,
    icon: Icons.live_tv_rounded,
    kind: ShellTabKind.live,
  ),
  ShellTabSpec(
    index: shellMediaLibraryTabIndex,
    icon: Icons.video_library_rounded,
    kind: ShellTabKind.mediaLibrary,
  ),
  ShellTabSpec(
    index: shellFavoritesTabIndex,
    icon: Icons.favorite_rounded,
    kind: ShellTabKind.favorites,
  ),
  ShellTabSpec(
    index: shellPlaylistsTabIndex,
    icon: Icons.playlist_play_rounded,
    kind: ShellTabKind.playlists,
  ),
  ShellTabSpec(
    index: shellEpgTabIndex,
    icon: Icons.calendar_month_rounded,
    kind: ShellTabKind.epg,
  ),
  ShellTabSpec(
    index: shellVodTabIndex,
    icon: Icons.movie_rounded,
    kind: ShellTabKind.vod,
    visibleInNavigation: false,
  ),
  ShellTabSpec(
    index: shellSeriesTabIndex,
    icon: Icons.tv_rounded,
    kind: ShellTabKind.series,
    visibleInNavigation: false,
  ),
  ShellTabSpec(
    index: shellDiagnosticsTabIndex,
    icon: Icons.terminal_rounded,
    kind: ShellTabKind.diagnostics,
    debugOnly: true,
  ),
  ShellTabSpec(
    index: shellSettingsTabIndex,
    icon: Icons.settings_rounded,
    kind: ShellTabKind.settings,
  ),
];

List<ShellTabSpec> shellVisibleTabs({required bool debugModeEnabled}) {
  return shellTabSpecs
      .where(
        (tab) =>
            tab.visibleInNavigation && (!tab.debugOnly || debugModeEnabled),
      )
      .toList(growable: false);
}

ShellTabSpec? shellTabForIndex(
  int activeIndex, {
  required bool debugModeEnabled,
}) {
  for (final tab in shellTabSpecs) {
    if (tab.index == activeIndex &&
        tab.visibleInNavigation &&
        (!tab.debugOnly || debugModeEnabled)) {
      return tab;
    }
  }
  return null;
}

bool shellTabVisible(int activeIndex, {required bool debugModeEnabled}) {
  return shellTabForIndex(activeIndex, debugModeEnabled: debugModeEnabled) !=
      null;
}

int shellFallbackTabIndex() {
  return shellSettingsTabIndex;
}

double shellSidebarWidth(bool expanded) {
  return expanded ? shellSidebarExpandedWidth : shellSidebarCollapsedWidth;
}

/// Maps the former standalone catalogue destinations to the shared hub.
int shellNavigationIndexFor(int activeIndex) {
  return switch (activeIndex) {
    shellVodTabIndex || shellSeriesTabIndex => shellMediaLibraryTabIndex,
    _ => activeIndex,
  };
}

/// Selects the matching Mediathek subtab for a legacy internal destination.
int shellLibrarySubtabFor(int activeIndex) {
  return switch (activeIndex) {
    shellSeriesTabIndex => 1,
    _ => 0,
  };
}
