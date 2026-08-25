import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/settings_layout_geometry.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/app/composition/settings/widgets/settings_screen.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_section_navigation.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

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
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
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
    expect(find.byType(SettingsSectionNavigation), findsOneWidget);
    expect(find.text('Playback'), findsOneWidget);
    expect(find.text('Discovery'), findsAtLeast(1));
    expect(find.text('Tabs and navigation'), findsOneWidget);
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
    expect(
      find.byKey(const PageStorageKey<String>('settings-scroll')),
      findsOneWidget,
    );
    expect(find.text('ADD PLAYLIST'), findsNothing);
  });

  testWidgets('settings remains usable at 200 percent text scaling', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(400, 720), textScaleFactor: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Live startup buffer'), findsOneWidget);
    expect(find.text('Preferred audio language'), findsOneWidget);
    expect(find.text('ADD PLAYLIST'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Restore defaults')).dy,
      greaterThan(tester.getTopLeft(find.text('Appearance').last).dy),
    );
  });

  testWidgets('compact section menu jumps to the selected settings card', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(400, 720));

    expect(
      find.byKey(const ValueKey('settings-compact-navigation')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('settings-section-menu-general')),
    );
    await tester.pumpAndSettle();
    final appearanceEntry = find.descendant(
      of: find.byType(MenuItemButton),
      matching: find.text('Appearance'),
    );
    expect(appearanceEntry, findsAtLeast(1));
    await tester.tap(appearanceEntry.last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-section-menu-appearance')),
      findsOneWidget,
    );
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const PageStorageKey<String>('settings-scroll')),
    );
    expect(scrollView.controller!.position.pixels, greaterThan(0));
  });

  testWidgets('wide scrollspy marks the final visible section', (tester) async {
    await pumpSettings(tester, size: const Size(1280, 720));
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const PageStorageKey<String>('settings-scroll')),
    );
    final position = scrollView.controller!.position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.pump();

    final appearanceItem = tester.widget<M3NavigationItem>(
      find.byKey(const ValueKey('settings-section-appearance')),
    );
    expect(appearanceItem.selected, isTrue);
  });

  testWidgets('wide settings keeps bounded content beside section navigation', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(1280, 720));

    expect(find.byKey(const ValueKey('settings-wide-group')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('settings-content'))).width,
      lessThanOrEqualTo(SettingsLayoutMetrics.contentMaxWidth),
    );
    expect(find.byType(SettingsSectionNavigation), findsOneWidget);
    expect(find.text('Playlist setup'), findsNothing);
    expect(find.text('Saved playlists'), findsNothing);
    expect(tester.takeException(), isNull);
  });

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
