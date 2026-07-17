import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';

void main() {
  test(
    'normalizePreferredAudioLanguage treats auto, empty, and null as no preference',
    () {
      expect(normalizePreferredAudioLanguage(null), isNull);
      expect(normalizePreferredAudioLanguage(''), isNull);
      expect(normalizePreferredAudioLanguage('  '), isNull);
      expect(normalizePreferredAudioLanguage('auto'), isNull);
      expect(normalizePreferredAudioLanguage(' AUTO '), isNull);
      expect(normalizePreferredAudioLanguage('de'), 'de');
    },
  );

  test('force stereo defaults to false', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    expect(await container.read(forceStereoEnabledProvider.future), isFalse);
  });

  test('force stereo persists through the provider and repository', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await container.read(forceStereoEnabledProvider.notifier).setEnabled(true);

    expect(container.read(forceStereoEnabledProvider).valueOrNull, isTrue);
    expect(await AppStateRepository(db).getForceStereoEnabled(), isTrue);

    await container.read(forceStereoEnabledProvider.notifier).setEnabled(false);

    expect(container.read(forceStereoEnabledProvider).valueOrNull, isFalse);
    expect(await AppStateRepository(db).getForceStereoEnabled(), isFalse);
  });

  test('preferred audio language defaults to null', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    expect(await container.read(preferredAudioLanguageProvider.future), isNull);
  });

  test(
    'live startup buffer provider defaults to 10 seconds and normalizes legacy 15 seconds',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      final repository = AppStateRepository(db);
      var freshContainerDisposed = false;
      final freshContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        await db.close();
      });
      addTearDown(() {
        if (!freshContainerDisposed) {
          freshContainer.dispose();
        }
      });

      expect(await freshContainer.read(playerBufferSecondsProvider.future), 10);

      await repository.setPlayerBufferSeconds(15);
      freshContainer.dispose();
      freshContainerDisposed = true;

      final migratedContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(migratedContainer.dispose);

      expect(
        await migratedContainer.read(playerBufferSecondsProvider.future),
        10,
      );
    },
  );

  test(
    'preferred audio language provider normalizes auto and persists null-compatible values',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await container
          .read(preferredAudioLanguageProvider.notifier)
          .setLanguage('de');
      expect(container.read(preferredAudioLanguageProvider).valueOrNull, 'de');
      expect(await AppStateRepository(db).getPreferredAudioLanguage(), 'de');

      await container
          .read(preferredAudioLanguageProvider.notifier)
          .setLanguage('auto');
      expect(
        container.read(preferredAudioLanguageProvider).valueOrNull,
        isNull,
      );
      expect(await AppStateRepository(db).getPreferredAudioLanguage(), isNull);

      await container
          .read(preferredAudioLanguageProvider.notifier)
          .setLanguage('');
      expect(
        container.read(preferredAudioLanguageProvider).valueOrNull,
        isNull,
      );
      expect(await AppStateRepository(db).getPreferredAudioLanguage(), isNull);
    },
  );
}
