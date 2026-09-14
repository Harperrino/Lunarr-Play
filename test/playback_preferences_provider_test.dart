import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/providers/playback_preferences_providers.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

void main() {
  test(
    'ambient previews publish immediately and writes retain call order',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = AppStateRepository(database);
      final container = ProviderContainer(
        overrides: [appStateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        playbackPreferencesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(playbackPreferencesProvider.future);
      final notifier = container.read(playbackPreferencesProvider.notifier);

      notifier.previewAmbientIntensity(0.74);
      expect(
        container
            .read(playbackPreferencesProvider)
            .requireValue
            .ambientIntensity,
        0.74,
      );

      final first = notifier.setAmbientIntensity(0.2);
      final second = notifier.setAmbientIntensity(0.8);
      expect(
        container
            .read(playbackPreferencesProvider)
            .requireValue
            .ambientIntensity,
        0.8,
      );
      await Future.wait<void>([first, second]);

      expect((await repository.getPlaybackPreferences()).ambientIntensity, 0.8);
    },
  );
}
