import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/settings_layout_geometry.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_screen.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_section_navigation.dart';

class _TestPlayerBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

class _TestVodPreBufferNotifier extends VodPreBufferTargetSecondsNotifier {
  @override
  Future<int> build() async => VodPreBufferTargetSecondsNotifier.defaultSeconds;
}

class _TestForceStereoNotifier extends ForceStereoEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

class _TestPreferredAudioLanguageNotifier
    extends PreferredAudioLanguageNotifier {
  @override
  Future<String?> build() async => null;
}

class _TestDebugModeNotifier extends DebugModeNotifier {
  @override
  Future<bool> build() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(
    WidgetTester tester, {
    required Size size,
    double devicePixelRatio = 1,
    double textScaleFactor = 1,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = size * devicePixelRatio;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        debugModeProvider.overrideWith(_TestDebugModeNotifier.new),
        playerBufferSecondsProvider.overrideWith(
          _TestPlayerBufferSecondsNotifier.new,
        ),
        vodPreBufferTargetSecondsProvider.overrideWith(
          _TestVodPreBufferNotifier.new,
        ),
        forceStereoEnabledProvider.overrideWith(_TestForceStereoNotifier.new),
        preferredAudioLanguageProvider.overrideWith(
          _TestPreferredAudioLanguageNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
            child: child!,
          ),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('settings contains only preference sections', (tester) async {
    await pumpSettings(tester, size: const Size(1280, 420));

    expect(tester.takeException(), isNull);
    expect(find.text('PLAYBACK'), findsOneWidget);
    expect(find.byType(SettingsSectionNavigation), findsNothing);
    expect(find.text('ADD PLAYLIST'), findsNothing);
    expect(find.text('SAVED PLAYLISTS'), findsNothing);
  });

  testWidgets('settings survives fractional-DPI resize', (tester) async {
    await pumpSettings(
      tester,
      size: const Size(1080, 370),
      devicePixelRatio: 1.25,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('settings-scroll')), findsOneWidget);
    expect(find.text('ADD PLAYLIST'), findsNothing);
  });

  testWidgets('settings remains usable at 200 percent text scaling', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(400, 720), textScaleFactor: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Live-Startpuffer'), findsOneWidget);
    expect(find.text('Bevorzugte Audiosprache'), findsOneWidget);
    expect(find.text('ADD PLAYLIST'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Standard wiederherstellen')).dy,
      greaterThan(tester.getTopLeft(find.text('Darstellung')).dy),
    );
  });

  testWidgets(
    'wide settings keeps bounded content without playlist navigation',
    (tester) async {
      await pumpSettings(tester, size: const Size(1280, 720));

      expect(find.byKey(const ValueKey('settings-wide-group')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('settings-content'))).width,
        lessThanOrEqualTo(SettingsLayoutMetrics.contentMaxWidth),
      );
      expect(find.byType(SettingsSectionNavigation), findsNothing);
      expect(find.text('Playlist setup'), findsNothing);
      expect(find.text('Saved playlists'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('settings navigation geometry remains available to legacy layouts', () {
    for (final width in [1024.0, 1080.0, 1280.0, 1600.0]) {
      expect(
        SettingsLayoutMetrics.hasSectionNavigation(
          availableWidth: width,
          textScaleFactor: 1,
        ),
        isTrue,
      );
    }
    expect(
      SettingsLayoutMetrics.hasSectionNavigation(
        availableWidth: 1280,
        textScaleFactor: 2,
      ),
      isFalse,
    );
    expect(
      SettingsLayoutMetrics.hasSectionNavigation(
        availableWidth: 1600,
        textScaleFactor: 2,
      ),
      isTrue,
    );
    expect(
      SettingsLayoutMetrics.navigationBreakpointFor(1),
      SettingsLayoutMetrics.sectionNavigationWidth +
          SettingsLayoutMetrics.navigationContentGap +
          SettingsLayoutMetrics.minimumContentWidth,
    );
  });
}
