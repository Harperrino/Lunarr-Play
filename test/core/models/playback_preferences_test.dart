import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';

void main() {
  test('playback preferences expose safe defaults', () {
    const preferences = PlaybackPreferences();
    expect(preferences.seekIntervalSeconds, 15);
    expect(preferences.trickplayEnabled, isTrue);
    expect(preferences.mediaSegmentSkipMode, MediaSegmentSkipMode.button);
    expect(preferences.nextEpisodeAutoplayEnabled, isTrue);
    expect(preferences.endcardCountdownSeconds, 10);
    expect(preferences.ambientBackgroundEnabled, isTrue);
    expect(preferences.ambientPreset, PlayerAmbientPreset.lunarr);
    expect(preferences.ambientCustomHueA, 215);
    expect(preferences.ambientCustomHueB, 285);
    expect(preferences.ambientIntensity, 0.55);
    expect(preferences.ambientMotion, PlayerAmbientMotion.slow);
  });

  test('invalid persisted values normalize to product defaults', () {
    expect(normalizePlaybackSeekInterval(12), 15);
    expect(normalizeEndcardCountdown(25), 10);
    expect(
      MediaSegmentSkipMode.fromStorage('legacy'),
      MediaSegmentSkipMode.button,
    );
    expect(
      PlayerAmbientPreset.fromStorage('legacy'),
      PlayerAmbientPreset.lunarr,
    );
    expect(PlayerAmbientMotion.fromStorage('legacy'), PlayerAmbientMotion.slow);
    expect(normalizeAmbientHue(double.nan), 215);
    expect(normalizeAmbientIntensity(4), 1);
  });
}
