import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/features/diagnostics/widgets/diagnostics_screen.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorites_screen.dart';
import 'package:m3uxtream_player/features/playlists/widgets/playlist_hub_screen.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/media_library_screen.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Feature body for sidebar indices 1â€“6 (non-live tabs).
class NonLiveTabBody extends StatelessWidget {
  const NonLiveTabBody({
    super.key,
    required this.activeIndex,
    required this.debugModeEnabled,
  });

  final int activeIndex;
  final bool debugModeEnabled;

  @override
  Widget build(BuildContext context) {
    final navigationIndex = shellNavigationIndexFor(activeIndex);
    final effectiveActiveIndex =
        shellTabVisible(navigationIndex, debugModeEnabled: debugModeEnabled)
        ? navigationIndex
        : shellFallbackTabIndex();

    switch (effectiveActiveIndex) {
      case shellPlaylistsTabIndex:
        return const PlaylistHubScreen();
      case shellFavoritesTabIndex:
        return const FavoritesScreen();
      case shellMediaLibraryTabIndex:
        return const MediaLibraryScreen();
      case shellEpgTabIndex:
        return const EpgScreen();
      case shellVodTabIndex:
        return const VodScreen();
      case shellSeriesTabIndex:
        return const SeriesScreen();
      case shellSettingsTabIndex:
        return const SettingsScreen();
      case shellDiagnosticsTabIndex:
        return debugModeEnabled
            ? const DiagnosticsScreen()
            : const SettingsScreen();
      default:
        return const _ComingSoonPlaceholder();
    }
  }
}

class _ComingSoonPlaceholder extends StatelessWidget {
  const _ComingSoonPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 48, color: colors.outline),
            const SizedBox(height: 16),
            Text(
              'Feature — Coming Soon',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'This section is planned for a future milestone.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
