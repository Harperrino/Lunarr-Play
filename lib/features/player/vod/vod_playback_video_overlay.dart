import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/vod/vod_hidden_video_surface.dart';

/// VOD-only bridge: keeps a [Video] mounted while the user is on VOD/Series tabs.
///
/// [PlayerPanel] exists only on the live tab; this overlay avoids audio-only prep.
class VodPlaybackVideoOverlay extends ConsumerWidget {
  const VodPlaybackVideoOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onLiveTab = ref.watch(activeSidebarIndexProvider) == 0;
    if (onLiveTab) return const SizedBox.shrink();

    final isSeekable = ref.watch(
      selectedChannelProvider.select(isSeekableChannel),
    );
    if (!isSeekable) return const SizedBox.shrink();

    return const IgnorePointer(child: VodHiddenVideoSurface());
  }
}
