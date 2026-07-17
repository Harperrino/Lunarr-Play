import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/services/live_composition_geometry.dart';

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
    required this.title,
    required this.subtitle,
    this.debugOnly = false,
    this.visibleInNavigation = true,
  });

  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool debugOnly;
  final bool visibleInNavigation;
}

const List<ShellTabSpec> shellTabSpecs = [
  ShellTabSpec(
    index: shellLiveTabIndex,
    icon: Icons.live_tv_rounded,
    title: 'Live TV',
    subtitle: 'Watch live channels — select a playlist and tap to play.',
  ),
  ShellTabSpec(
    index: shellMediaLibraryTabIndex,
    icon: Icons.video_library_rounded,
    title: 'Mediathek',
    subtitle:
        'Filme, Serien und Später ansehen in einer gemeinsamen Mediathek.',
  ),
  ShellTabSpec(
    index: shellFavoritesTabIndex,
    icon: Icons.favorite_rounded,
    title: 'Favorites',
    subtitle: 'Quick access to your favourite live channels.',
  ),
  ShellTabSpec(
    index: shellPlaylistsTabIndex,
    icon: Icons.playlist_play_rounded,
    title: 'Playlists',
    subtitle: 'Switch playlists and manage which categories are visible.',
  ),
  ShellTabSpec(
    index: shellEpgTabIndex,
    icon: Icons.calendar_month_rounded,
    title: 'EPG Guide',
    subtitle:
        'TV programme guide for the active playlist — tap a show to watch live.',
  ),
  ShellTabSpec(
    index: shellVodTabIndex,
    icon: Icons.movie_rounded,
    title: 'VOD Movies',
    subtitle:
        'Browse movies from your active playlist — tap to play on the Live tab.',
    visibleInNavigation: false,
  ),
  ShellTabSpec(
    index: shellSeriesTabIndex,
    icon: Icons.tv_rounded,
    title: 'Series',
    subtitle:
        'Browse series — open a show for episodes and resume where you left off.',
    visibleInNavigation: false,
  ),
  ShellTabSpec(
    index: shellDiagnosticsTabIndex,
    icon: Icons.terminal_rounded,
    title: 'Diagnostics / Logs',
    subtitle: 'Debug-only log console and runtime diagnostics.',
    debugOnly: true,
  ),
  ShellTabSpec(
    index: shellSettingsTabIndex,
    icon: Icons.settings_rounded,
    title: 'Settings',
    subtitle: 'Add, sync, and manage M3U & Xtream playlists.',
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
