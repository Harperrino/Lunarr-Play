import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/features/settings/providers/appearance_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/appearance_settings_card.dart';
import 'package:m3uxtream_player/shared/theme/appearance_preferences.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'appearance sliders update, persist, and reset in high contrast',
    (tester) async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.highContrastDarkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: AppearanceSettingsCard(compact: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final sliders = find.byType(M3ExpressiveSlider);
      expect(sliders, findsNWidgets(2));
      expect(
        tester.widget<M3ExpressiveSlider>(sliders.first).size,
        M3ExpressiveSliderSize.m,
      );
      expect(find.byType(Slider), findsNothing);

      final accentRect = tester.getRect(sliders.first);
      await tester.tapAt(
        Offset(accentRect.left + accentRect.width * 0.75, accentRect.center.dy),
      );
      final surfaceRect = tester.getRect(sliders.last);
      await tester.tapAt(
        Offset(
          surfaceRect.left + surfaceRect.width * 0.8,
          surfaceRect.center.dy,
        ),
      );
      await tester.pump();

      final changed = container.read(appearancePreferencesProvider);
      expect(
        changed.accentHue,
        isNot(AppearancePreferences.defaults.accentHue),
      );
      expect(
        changed.surfaceTone,
        isNot(AppearancePreferences.defaults.surfaceTone),
      );
      expect(
        await AppStateRepository(db).getAppearanceAccentHue(),
        closeTo(changed.accentHue, 0.01),
      );
      expect(
        await AppStateRepository(db).getAppearanceSurfaceTone(),
        closeTo(changed.surfaceTone, 0.001),
      );

      await tester.tap(find.text('Standard wiederherstellen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        container.read(appearancePreferencesProvider),
        AppearancePreferences.defaults,
      );
      expect(
        await AppStateRepository(db).getAppearanceAccentHue(),
        AppearancePreferences.defaultAccentHue,
      );
      expect(
        await AppStateRepository(db).getAppearanceSurfaceTone(),
        AppearancePreferences.defaultSurfaceTone,
      );
    },
  );
}
