import 'package:flutter/material.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Playback controls of the Jellyfin player (V1): play/pause, seek bar,
/// position/duration, volume, mute and stop. Observes the player state
/// directly from the Jellyfin [JellyfinPlayerController].
class JellyfinPlayerControls extends StatelessWidget {
  const JellyfinPlayerControls({
    super.key,
    required this.controller,
    required this.onStop,
  });

  final JellyfinPlayerController controller;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<JellyfinPlayerState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final l10n = context.l10n;
        final controlsEnabled = state.initialized && !state.error;
        final durationSeconds = state.duration.inSeconds;
        final positionSeconds = durationSeconds > 0
            ? state.position.inSeconds.clamp(0, durationSeconds)
            : 0;
        final durationLabel = durationSeconds > 0
            ? jellyfinFormatDuration(state.duration)
            : l10n.jellyfinDurationUnknown;

        return Material(
          color: colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: state.playing
                      ? l10n.playerPauseTooltip
                      : l10n.playerPlayTooltip,
                  onPressed: controlsEnabled
                      ? () => controller.togglePlayPause()
                      : null,
                  icon: Icon(
                    state.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                Text(
                  jellyfinFormatDuration(state.position),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Expanded(
                  child: Slider(
                    value: positionSeconds.toDouble(),
                    max: durationSeconds > 0
                        ? durationSeconds.toDouble()
                        : 1,
                    onChanged: controlsEnabled && durationSeconds > 0
                        ? (value) =>
                              controller.seek(Duration(seconds: value.round()))
                        : null,
                  ),
                ),
                Text(
                  durationLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: l10n.jellyfinVolumeTooltip,
                  child: SizedBox(
                    width: 110,
                    child: Slider(
                      value: state.volume,
                      onChanged: (value) => controller.setVolume(value),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: state.muted
                      ? l10n.playerUnmuteTooltip
                      : l10n.playerMuteTooltip,
                  onPressed: () => controller.toggleMute(),
                  icon: Icon(
                    state.muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                ),
                IconButton(
                  tooltip: l10n.jellyfinStopTooltip,
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
