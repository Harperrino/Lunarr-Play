import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

enum SettingsSection { general, playlistSetup, savedPlaylists }

/// Local, presentation-only navigation for the wide Settings layout.
class SettingsSectionNavigation extends StatelessWidget {
  const SettingsSectionNavigation({
    required this.onGeneralSelected,
    required this.onPlaylistSetupSelected,
    required this.onSavedPlaylistsSelected,
    required this.selectedSection,
    super.key,
  });

  final VoidCallback onGeneralSelected;
  final VoidCallback onPlaylistSetupSelected;
  final VoidCallback onSavedPlaylistsSelected;
  final SettingsSection selectedSection;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.low,
      elevation: AppElevation.level1,
      padding: const EdgeInsets.all(12),
      child: M3NavigationSection(
        title: 'Sections',
        padding: EdgeInsets.zero,
        mainAxisSize: MainAxisSize.min,
        children: [
          M3NavigationItem(
            label: 'General',
            icon: Icons.tune_rounded,
            selected: selectedSection == SettingsSection.general,
            visualRole: M3NavigationItemVisualRole.settingsNavigation,
            onPressed: onGeneralSelected,
          ),
          M3NavigationItem(
            label: 'Playlist setup',
            icon: Icons.add_circle_outline_rounded,
            selected: selectedSection == SettingsSection.playlistSetup,
            visualRole: M3NavigationItemVisualRole.settingsNavigation,
            onPressed: onPlaylistSetupSelected,
          ),
          M3NavigationItem(
            label: 'Saved playlists',
            icon: Icons.playlist_play_rounded,
            selected: selectedSection == SettingsSection.savedPlaylists,
            visualRole: M3NavigationItemVisualRole.settingsNavigation,
            onPressed: onSavedPlaylistsSelected,
          ),
        ],
      ),
    );
  }
}
