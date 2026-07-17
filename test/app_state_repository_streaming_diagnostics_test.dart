import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

void main() {
  test('persists streaming diagnostics toggles in AppStates', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final repository = AppStateRepository(db);

    await repository.setStreamingAutoFallbackEnabled(false);
    await repository.setStreamingShowDiagnosisOnError(false);

    expect(await repository.getStreamingAutoFallbackEnabled(), isFalse);
    expect(await repository.getStreamingShowDiagnosisOnError(), isFalse);
  });

  test(
    'returns defaults for streaming diagnostics toggles when absent',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final repository = AppStateRepository(db);

      expect(await repository.getStreamingAutoFallbackEnabled(), isTrue);
      expect(await repository.getStreamingShowDiagnosisOnError(), isTrue);
    },
  );

  test(
    'persists inactive playlist ids and defaults playlists to active',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final repository = AppStateRepository(db);

      expect(await repository.isPlaylistActive(42), isTrue);

      await repository.setPlaylistActive(42, false);

      expect(await repository.isPlaylistActive(42), isFalse);
      expect(await repository.getInactivePlaylistIds(), contains(42));

      await repository.setPlaylistActive(42, true);

      expect(await repository.isPlaylistActive(42), isTrue);
      expect(await repository.getInactivePlaylistIds(), isNot(contains(42)));
    },
  );

  test(
    'persists live startup buffer seconds including immediate start',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(() async => db.close());

      final repository = AppStateRepository(db);

      await repository.setPlayerBufferSeconds(0);
      expect(await repository.getPlayerBufferSeconds(), equals(0));

      await repository.setPlayerBufferSeconds(5);
      expect(await repository.getPlayerBufferSeconds(), equals(5));

      await repository.setPlayerBufferSeconds(15);
      expect(await repository.getPlayerBufferSeconds(), equals(15));

      await repository.setPlayerBufferSeconds(60);
      expect(await repository.getPlayerBufferSeconds(), equals(60));

      await repository.setPlayerBufferSeconds(120);
      expect(await repository.getPlayerBufferSeconds(), equals(120));

      await repository.setPlayerBufferSeconds(200);
      expect(await repository.getPlayerBufferSeconds(), equals(120));
    },
  );
}
