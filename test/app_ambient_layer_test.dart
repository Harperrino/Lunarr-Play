import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/app/shell/app_ambient_layer.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/providers/playback_preferences_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_ambient_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell adapter fills its window and reacts to preferences', (
    tester,
  ) async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    await container.read(playbackPreferencesProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SizedBox.expand(
            key: ValueKey('ambient-host'),
            child: AppAmbientLayer(animationEnabled: false),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppAmbientBackground), findsOneWidget);
    expect(
      tester
          .widget<AppAmbientBackground>(find.byType(AppAmbientBackground))
          .animationEnabled,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(AppAmbientBackground)),
      tester.getSize(find.byKey(const ValueKey('ambient-host'))),
    );

    await container
        .read(playbackPreferencesProvider.notifier)
        .setAmbientBackgroundEnabled(false);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('app-ambient-background-disabled')),
      findsOneWidget,
    );
  });
}
