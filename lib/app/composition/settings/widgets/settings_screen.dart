import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/appearance_settings_card.dart';
import 'package:m3uxtream_player/app/composition/settings/widgets/playback_settings_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_debug_mode_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_layout.dart';

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
          topSection: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsDebugModeCard(
                isEnabled: debugModeAsync.valueOrNull ?? false,
                isLoading: debugModeAsync.isLoading,
                compact: compact,
                onChanged: (value) =>
                    ref.read(debugModeProvider.notifier).setEnabled(value),
              ),
              SizedBox(height: compact ? 12 : 16),
              PlaybackSettingsCard(compact: compact),
              SizedBox(height: compact ? 12 : 16),
              AppearanceSettingsCard(compact: compact),
            ],
          ),
        );
      },
    );
  }
}
