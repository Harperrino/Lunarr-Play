import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/providers/playback_preferences_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_ambient_background.dart';

/// App-composition adapter that keeps Riverpod out of the shared renderer.
class AppAmbientLayer extends ConsumerWidget {
  const AppAmbientLayer({super.key, required this.animationEnabled});

  final bool animationEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(playbackPreferencesProvider).valueOrNull ??
        const PlaybackPreferences();
    return RepaintBoundary(
      child: AppAmbientBackground(
        preferences: preferences,
        animationEnabled: animationEnabled,
      ),
    );
  }
}
