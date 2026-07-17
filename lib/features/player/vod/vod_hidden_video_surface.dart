import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

/// Hidden [Video] so mpv binds video output while the user stays on VOD/Series tabs.
///
/// The live [PlayerPanel] is only mounted on sidebar index 0; without this,
/// VOD prep would decode audio-only until the second play attempt.
class VodHiddenVideoSurface extends ConsumerWidget {
  const VodHiddenVideoSurface({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(selectedChannelProvider.select(isSeekableChannel))) {
      return const SizedBox.shrink();
    }

    final playbackContext = ref.watch(
      playerNotifierProvider.select(
        (state) => (
          player: state.valueOrNull?.player,
          playbackUri: state.valueOrNull?.playbackUri,
        ),
      ),
    );
    final player = playbackContext.player;
    final playbackUri = playbackContext.playbackUri;
    if (player == null || playbackUri == null) {
      return const SizedBox.shrink();
    }

    final controller = ref
        .read(playerNotifierProvider.notifier)
        .videoControllerFor(player);

    return Opacity(
      opacity: 0,
      child: SizedBox(
        width: 64,
        height: 36,
        child: Video(
          key: ValueKey('vod-hidden-${playbackContext.playbackUri}'),
          controller: controller,
          controls: NoVideoControls,
        ),
      ),
    );
  }
}
