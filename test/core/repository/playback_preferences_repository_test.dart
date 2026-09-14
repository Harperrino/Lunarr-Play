import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

void main() {
  test('playback preferences persist through the AppState store', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = AppStateRepository(db);

    await repository.setPlaybackSeekIntervalSeconds(30);
    await repository.setJellyfinTrickplayEnabled(false);
    await repository.setJellyfinMediaSegmentSkipMode(
      MediaSegmentSkipMode.automatic,
    );
    await repository.setJellyfinNextEpisodeAutoplayEnabled(false);
    await repository.setJellyfinEndcardCountdownSeconds(20);
    await repository.setPlayerAmbientBackgroundEnabled(false);
    await repository.setPlayerAmbientPreset(PlayerAmbientPreset.custom);
    await repository.setPlayerAmbientCustomHueA(123);
    await repository.setPlayerAmbientCustomHueB(321);
    await repository.setPlayerAmbientIntensity(0.7);
    await repository.setPlayerAmbientMotion(PlayerAmbientMotion.fast);

    final stored = await repository.getPlaybackPreferences();
    expect(stored.seekIntervalSeconds, 30);
    expect(stored.trickplayEnabled, isFalse);
    expect(stored.mediaSegmentSkipMode, MediaSegmentSkipMode.automatic);
    expect(stored.nextEpisodeAutoplayEnabled, isFalse);
    expect(stored.endcardCountdownSeconds, 20);
    expect(stored.ambientBackgroundEnabled, isFalse);
    expect(stored.ambientPreset, PlayerAmbientPreset.custom);
    expect(stored.ambientCustomHueA, 123);
    expect(stored.ambientCustomHueB, 321);
    expect(stored.ambientIntensity, 0.7);
    expect(stored.ambientMotion, PlayerAmbientMotion.fast);
  });

  test('invalid raw AppState values fall back to safe defaults', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = AppStateRepository(db);
    await db.customStatement(
      "INSERT INTO app_states (key, value) VALUES "
      "('playback_seek_interval_seconds', '12'), "
      "('jellyfin_trickplay_enabled', 'invalid'), "
      "('jellyfin_media_segment_skip_mode', 'legacy'), "
      "('jellyfin_next_episode_autoplay_enabled', 'invalid'), "
      "('jellyfin_endcard_countdown_seconds', '25'), "
      "('player_ambient_background_enabled', 'invalid'), "
      "('player_ambient_preset', 'legacy'), "
      "('player_ambient_custom_hue_a', 'not-a-number'), "
      "('player_ambient_custom_hue_b', '999'), "
      "('player_ambient_intensity', '-1'), "
      "('player_ambient_motion', 'legacy')",
    );

    final stored = await repository.getPlaybackPreferences();
    expect(stored.seekIntervalSeconds, 15);
    expect(stored.trickplayEnabled, isTrue);
    expect(stored.mediaSegmentSkipMode, MediaSegmentSkipMode.button);
    expect(stored.nextEpisodeAutoplayEnabled, isTrue);
    expect(stored.endcardCountdownSeconds, 10);
    expect(stored.ambientBackgroundEnabled, isTrue);
    expect(stored.ambientPreset, PlayerAmbientPreset.lunarr);
    final canonicalPreset = await db
        .customSelect(
          "SELECT value FROM app_states WHERE key = 'player_ambient_preset'",
        )
        .getSingle();
    expect(canonicalPreset.read<String>('value'), 'lunarr');
    expect(stored.ambientCustomHueA, 215);
    expect(stored.ambientCustomHueB, 360);
    expect(stored.ambientIntensity, 0);
    expect(stored.ambientMotion, PlayerAmbientMotion.slow);
  });
}
