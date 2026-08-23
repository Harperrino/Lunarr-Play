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

    final stored = await repository.getPlaybackPreferences();
    expect(stored.seekIntervalSeconds, 30);
    expect(stored.trickplayEnabled, isFalse);
    expect(stored.mediaSegmentSkipMode, MediaSegmentSkipMode.automatic);
    expect(stored.nextEpisodeAutoplayEnabled, isFalse);
    expect(stored.endcardCountdownSeconds, 20);
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
      "('jellyfin_endcard_countdown_seconds', '25')",
    );

    final stored = await repository.getPlaybackPreferences();
    expect(stored.seekIntervalSeconds, 15);
    expect(stored.trickplayEnabled, isTrue);
    expect(stored.mediaSegmentSkipMode, MediaSegmentSkipMode.button);
    expect(stored.nextEpisodeAutoplayEnabled, isTrue);
    expect(stored.endcardCountdownSeconds, 10);
  });
}
