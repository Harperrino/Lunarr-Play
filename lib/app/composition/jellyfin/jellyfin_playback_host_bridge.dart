import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

/// Tiny app-level adapter between the Jellyfin feature and the existing
/// Lunarr/Xtream player.
///
/// It only CALLS existing public APIs (`stopStream`) and never modifies them.
/// When no Xtream stream is active the call is a no-op.
class JellyfinPlaybackHostBridge {
  const JellyfinPlaybackHostBridge._();

  static Future<void> stopExistingLunarrPlayback(Ref ref) async {
    final state = await ref.read(playerNotifierProvider.future);
    if (!state.isPlaying && state.playbackUri == null) {
      return;
    }
    await ref.read(playerNotifierProvider.notifier).stopStream();
  }
}
