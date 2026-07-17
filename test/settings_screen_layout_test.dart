import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/settings_layout_geometry.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_screen.dart';
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

class _TestInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

class _TestDebugModeNotifier extends DebugModeNotifier {
  @override
  Future<bool> build() async => false;
}

class _TestPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _TestEpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

class _TestPlaylistFormNotifier extends PlaylistFormNotifier {
  @override
  Future<void> build() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSettings(
    WidgetTester tester, {
    required Size size,
    double devicePixelRatio = 1,
    double textScaleFactor = 1,
    List<Playlist> playlists = const <Playlist>[],
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = size * devicePixelRatio;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        playlistsStreamProvider.overrideWith((ref) => Stream.value(playlists)),
        inactivePlaylistIdsProvider.overrideWith(
          _TestInactivePlaylistIdsNotifier.new,
        ),
        playlistFormNotifierProvider.overrideWith(
          _TestPlaylistFormNotifier.new,
        ),
        playlistSyncNotifierProvider.overrideWith(
          _TestPlaylistSyncNotifier.new,
        ),
        epgSyncNotifierProvider.overrideWith(_TestEpgSyncNotifier.new),
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

  testWidgets('settings tab stays within a compact viewport', (tester) async {
    await pumpSettings(tester, size: const Size(1280, 420));

    expect(tester.takeException(), isNull);
    expect(find.text('PLAYBACK'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is DropdownMenu),
      findsNWidgets(2),
    );
    await tester.scrollUntilVisible(
      find.text('ADD PLAYLIST'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('ADD PLAYLIST'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SAVED PLAYLISTS'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('SAVED PLAYLISTS'), findsOneWidget);
  });

  testWidgets('settings tab survives fractional-DPI resize', (tester) async {
    await pumpSettings(
      tester,
      size: const Size(1080, 370),
      devicePixelRatio: 1.25,
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('ADD PLAYLIST'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('ADD PLAYLIST'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SAVED PLAYLISTS'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('SAVED PLAYLISTS'), findsOneWidget);
  });

  testWidgets('playlist cards fit beside an expanded sidebar and scroll', (
    tester,
  ) async {
    final now = DateTime(2026, 6, 23, 12);
    final playlists = List<Playlist>.generate(
      5,
      (index) => Playlist(
        id: index + 1,
        name: 'Example Playlist ${index + 1} With A Long Name',
        type: index.isEven ? 'xtream' : 'm3u',
        urlOrHost: 'https://example.invalid/source/${index + 1}',
        createdAt: now,
        lastSyncedAt: now,
        epgUrl: 'https://example.invalid/epg/${index + 1}.xml',
        epgLastSyncedAt: now,
      ),
    );

    // 1080 px window minus the expanded 236 px sidebar and shell padding.
    await pumpSettings(
      tester,
      size: const Size(796, 650),
      devicePixelRatio: 1.25,
      playlists: playlists,
    );

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings remains usable at 200 percent text scaling', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(1280, 720), textScaleFactor: 2);

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('ADD PLAYLIST'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('ADD PLAYLIST'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SAVED PLAYLISTS'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('SAVED PLAYLISTS'), findsOneWidget);
  });

  testWidgets('compact settings stay overflow-free at 200 percent scaling', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(400, 720), textScaleFactor: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Live-Startpuffer'), findsOneWidget);
    expect(find.text('Bevorzugte Audiosprache'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Standard wiederherstellen')).dy,
      greaterThan(tester.getTopLeft(find.text('Darstellung')).dy),
    );
  });

  testWidgets('wide settings uses bounded content and section navigation', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(1280, 720));

    final wideGroup = find.byKey(const ValueKey('settings-wide-group'));
    expect(
      tester.getSize(wideGroup).width,
      SettingsLayoutMetrics.desktopGroupMaxWidth,
    );
    expect(tester.getTopLeft(wideGroup).dx, 0);

    expect(
      tester.getSize(find.byKey(const ValueKey('settings-content'))).width,
      lessThanOrEqualTo(760),
    );
    expect(
      tester.getSize(find.byType(SettingsSectionNavigation)).width,
      SettingsLayoutMetrics.sectionNavigationWidth,
    );
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Playlist setup'), findsOneWidget);
    expect(find.text('Saved playlists'), findsOneWidget);

    await tester.tap(find.text('Playlist setup'));
    await tester.pumpAndSettle();
    expect(find.text('ADD PLAYLIST'), findsOneWidget);
    final navigationItems = find.descendant(
      of: find.byType(SettingsSectionNavigation),
      matching: find.byType(M3NavigationItem),
    );
    expect(
      tester.widget<M3NavigationItem>(navigationItems.at(0)).selected,
      isFalse,
    );
    expect(
      tester.widget<M3NavigationItem>(navigationItems.at(1)).selected,
      isTrue,
    );
    expect(
      tester.widget<M3NavigationItem>(navigationItems.at(2)).selected,
      isFalse,
    );
    final selectedNavigationItem = find.ancestor(
      of: find.text('Playlist setup'),
      matching: find.byType(M3NavigationItem),
    );
    final colors = Theme.of(tester.element(selectedNavigationItem)).colorScheme;
    expect(
      tester
          .widgetList<Material>(
            find.descendant(
              of: selectedNavigationItem,
              matching: find.byType(Material),
            ),
          )
          .any((material) => material.color == colors.secondaryContainer),
      isTrue,
    );
    expect(
      tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(SettingsSectionNavigation),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .every((container) => container.decoration == null),
      isTrue,
    );

    await tester.drag(
      find.byKey(const ValueKey('settings-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('SAVED PLAYLISTS'),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<M3NavigationItem>(navigationItems.at(2)).selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  test('settings navigation breakpoint accounts for all layout units', () {
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
