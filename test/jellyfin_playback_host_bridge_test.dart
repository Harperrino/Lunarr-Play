import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:m3uxtream_player/app/composition/jellyfin/jellyfin_playback_host_bridge.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';

import 'support/fake_media_player.dart';

class _StoppingPlayer extends Fake implements Player {
  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

ProviderContainer _container(PlayerState state) {
  return ProviderContainer(
    overrides: [
      playerNotifierProvider.overrideWith(() => FixedPlayerNotifier(state)),
      jellyfinExistingPlaybackStopperProvider.overrideWith(
        (ref) => () => JellyfinPlaybackHostBridge.stopExistingLunarrPlayback(ref),
      ),
    ],
  );
}

void main() {
  test('stops the existing Lunarr player only when a stream is active', () async {
    final player = _StoppingPlayer();
    final container = _container(
      PlayerState(
        player: player,
        playbackUri: 'https://example.com/live.m3u8',
        isPlaying: true,
        volume: 0.5,
        isBuffering: false,
        isLiveStartupBuffering: false,
      ),
    );
    addTearDown(container.dispose);

    final stopper = container.read(jellyfinExistingPlaybackStopperProvider);
    expect(stopper, isNotNull);
    // Warm the player notifier so the bridge sees AsyncData, not the first
    // AsyncLoading of a cold read.
    await container.read(playerNotifierProvider.future);
    await stopper!();

    expect(player.stopCount, 1);
  });

  test('is a no-op when no Xtream stream is active', () async {
    final player = _StoppingPlayer();
    final container = _container(
      PlayerState(
        player: player,
        playbackUri: null,
        isPlaying: false,
        volume: 0.5,
        isBuffering: false,
        isLiveStartupBuffering: false,
      ),
    );
    addTearDown(container.dispose);

    final stopper = container.read(jellyfinExistingPlaybackStopperProvider)!;
    await stopper();

    expect(player.stopCount, 0);
  });

  test('defaults to a no-op when the host bridge is not wired', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final stopper = container.read(jellyfinExistingPlaybackStopperProvider);
    expect(stopper, isNull);
  });
}
