import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/appearance_settings_card.dart';
import 'package:m3uxtream_player/app/composition/settings/widgets/playback_settings_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_debug_mode_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_layout.dart';
import 'package:m3uxtream_player/features/settings/widgets/shell_tab_visibility_settings_card.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_settings_card.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Settings is intentionally limited to app, display, diagnostic, and
/// playback preferences. Playlist CRUD and EPG operations belong to the
/// Playlists tab and are not duplicated here.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugModeAsync = ref.watch(debugModeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 760;
        return SettingsLayout(
          sections: [
            SettingsSectionDescriptor(
              id: SettingsSectionId.general,
              icon: Icons.tune_rounded,
              label: context.l10n.settingsSectionGeneral,
              child: SettingsDebugModeCard(
                isEnabled: debugModeAsync.valueOrNull ?? false,
                isLoading: debugModeAsync.isLoading,
                compact: compact,
                onChanged: (value) =>
                    ref.read(debugModeProvider.notifier).setEnabled(value),
              ),
            ),
            SettingsSectionDescriptor(
              id: SettingsSectionId.playback,
              icon: Icons.play_circle_outline_rounded,
              label: context.l10n.settingsSectionPlayback,
              child: PlaybackSettingsCard(compact: compact),
            ),
            SettingsSectionDescriptor(
              id: SettingsSectionId.discovery,
              icon: Icons.explore_outlined,
              label: context.l10n.settingsSectionDiscovery,
              child: DiscoverySettingsCard(compact: compact),
            ),
            SettingsSectionDescriptor(
              id: SettingsSectionId.navigation,
              icon: Icons.tab_rounded,
              label: context.l10n.settingsSectionNavigation,
              child: ShellTabVisibilitySettingsCard(compact: compact),
            ),
            SettingsSectionDescriptor(
              id: SettingsSectionId.appearance,
              icon: Icons.palette_outlined,
              label: context.l10n.settingsSectionAppearance,
              child: AppearanceSettingsCard(compact: compact),
            ),
          ],
        );
      },
    );
  }
}
