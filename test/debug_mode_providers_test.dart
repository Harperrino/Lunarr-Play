import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';

void main() {
  test(
    'persists debug mode in AppStates and restores it through Riverpod',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      expect(await container.read(debugModeProvider.future), isFalse);

      await container.read(debugModeProvider.notifier).setEnabled(true);

      expect(container.read(debugModeProvider).valueOrNull, isTrue);
      expect(await AppStateRepository(db).getDebugModeEnabled(), isTrue);
    },
  );
}
