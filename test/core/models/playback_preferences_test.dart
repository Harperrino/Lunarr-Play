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
  });

  test('invalid persisted values normalize to product defaults', () {
    expect(normalizePlaybackSeekInterval(12), 15);
    expect(normalizeEndcardCountdown(25), 10);
    expect(
      MediaSegmentSkipMode.fromStorage('legacy'),
      MediaSegmentSkipMode.button,
    );
  });
}
