@Tags(['native'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState, Playlist;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/app/shell/shell_sidebar.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/live_composition_geometry.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_list_panel.dart';
import 'package:m3uxtream_player/features/channels/widgets/live_category_sidebar.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_providers.dart';
import 'package:m3uxtream_player/features/player/widgets/live_tab_shell.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_edge_handle.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';

import 'helpers/media_kit_test_init.dart';
import 'support/fake_media_player.dart';

class _TestBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

class _TestPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _TestEpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

class _TestInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

class _TestPinnedGroupsNotifier extends PinnedGroupsNotifier {
  @override
  Future<List<String>> build() async => const <String>[];
}

class _TestPlayerNotifier extends PlayerNotifier {
  @override
  Future<PlayerState> build() async => PlayerState(
    player: FakeMediaPlayer(),
    playbackUri: null,
    isPlaying: false,
    volume: 0.5,
    isBuffering: false,
    isLiveStartupBuffering: false,
  );

  @override
  VideoController videoControllerFor(Player player) => VideoController(player);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensureMediaKitForTests);

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    required bool immersive,
    bool sidebarExpanded = false,
    double textScaleFactor = 1,
    bool withCategories = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError(
            'Live shell composition tests must not open the database',
          ),
        ),
        playlistsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Playlist>[]),
        ),
        liveChannelsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Channel>[]),
        ),
        playlistSyncNotifierProvider.overrideWith(
          _TestPlaylistSyncNotifier.new,
        ),
        epgSyncNotifierProvider.overrideWith(_TestEpgSyncNotifier.new),
        inactivePlaylistIdsProvider.overrideWith(
          _TestInactivePlaylistIdsNotifier.new,
        ),
        playerBufferSecondsProvider.overrideWith(
          _TestBufferSecondsNotifier.new,
        ),
        playerNotifierProvider.overrideWith(_TestPlayerNotifier.new),
        currentProgramTitleForSelectedChannelProvider.overrideWith(
          (ref) => null,
        ),
        if (withCategories) ...[
          channelGroupsProvider.overrideWithValue(const <String>['News']),
          pinnedGroupsProvider.overrideWith(_TestPinnedGroupsNotifier.new),
        ],
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
          home: Scaffold(
            body: LiveTabShell(
              immersive: immersive,
              playerPanelKey: _playerKey,
              activeSidebarIndex: 0,
              debugModeEnabled: false,
              sidebarExpanded: sidebarExpanded,
              onSidebarTap: (_) {},
              onSidebarToggle: () {},
              headerTitle: 'Live TV',
              headerSubtitle: 'Watch live television',
              headerExtras: const GlobalSearchField(),
              onToggleFullscreen: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(LiveTabShell.layoutTransitionDuration);
  }

  Future<void> expectWindowedComposition(
    WidgetTester tester,
    double availableWidth,
  ) async {
    const contentHeight = 600.0;
    final headerLayout = LiveHeaderLayoutMetrics.resolve(
      availableWidth: availableWidth,
      textScaleFactor: 1,
    );
    final bodyTop = LiveLayoutMetrics.headerTopOffset(
      headerHeight: headerLayout.height,
    );

    final totalWidth =
        LiveLayoutMetrics.sidebarWidthFor(expanded: false) +
        (LiveLayoutMetrics.outerPadding * 2) +
        availableWidth;
    await pumpShell(
      tester,
      size: Size(
        totalWidth,
        bodyTop + contentHeight + LiveLayoutMetrics.outerPadding,
      ),
      immersive: false,
    );

    final bounds = Rect.fromLTWH(
      LiveLayoutMetrics.sidebarWidthFor(expanded: false) +
          LiveLayoutMetrics.outerPadding,
      bodyTop,
      availableWidth,
      contentHeight,
    );
    final expected = LiveCompositionGeometry.calculate(contentBounds: bounds);

    _expectRect(tester, find.byKey(_playerKey), expected.playerRect);
    if (expected.channelListRect case final channelListRect?) {
      _expectRect(tester, find.byType(ChannelListPanel), channelListRect);
    } else {
      expect(find.byType(ChannelListPanel), findsNothing);
      expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
    }

    final categoryFinder = find.byType(LiveCategorySidebar);
    if (expected.categoryRect case final categoryRect?) {
      expect(categoryFinder, findsOneWidget);
      _expectRect(tester, categoryFinder, categoryRect);
    } else {
      expect(categoryFinder, findsNothing);
    }
    expect(find.byKey(_playerKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  for (final availableWidth in [719.0, 720.0, 1199.0, 1200.0, 1600.0]) {
    testWidgets(
      'uses M5a rectangles at ${availableWidth.toInt()}px Live width',
      (tester) => expectWindowedComposition(tester, availableWidth),
    );
  }

  for (final testCase in const [
    (availableWidth: 719.0, sidebarExpanded: true),
    (availableWidth: 720.0, sidebarExpanded: false),
    (availableWidth: 1199.0, sidebarExpanded: false),
    (availableWidth: 1200.0, sidebarExpanded: false),
  ]) {
    testWidgets('keeps the scaled header and body separate at '
        '${testCase.availableWidth.toInt()}px Live width', (tester) async {
      const textScaleFactor = 2.0;
      // The compact 719 px composition stacks player and channel list. Keep
      // its existing panels tall enough at 200% so this regression targets
      // the header breakpoint rather than the separate short-height layout.
      const contentHeight = 720.0;
      final headerLayout = LiveHeaderLayoutMetrics.resolve(
        availableWidth: testCase.availableWidth,
        textScaleFactor: textScaleFactor,
      );
      final headerPlacement = LiveHeaderPlacementMetrics.resolve(
        headerHeight: headerLayout.height,
      );
      final sidebarWidth = LiveLayoutMetrics.sidebarWidthFor(
        expanded: testCase.sidebarExpanded,
      );
      final totalWidth =
          sidebarWidth +
          (LiveLayoutMetrics.outerPadding * 2) +
          testCase.availableWidth;
      final bodyTop = headerPlacement.bodyTop;

      await pumpShell(
        tester,
        size: Size(
          totalWidth,
          bodyTop + contentHeight + LiveLayoutMetrics.outerPadding,
        ),
        immersive: false,
        sidebarExpanded: testCase.sidebarExpanded,
        textScaleFactor: textScaleFactor,
      );

      final headerRect = _rectFor(tester, find.byKey(LiveTabShell.headerKey));
      expect(headerRect.top, headerPlacement.top);
      expect(headerRect.height, headerPlacement.height);
      expect(headerRect.bottom, bodyTop);

      final expected = LiveCompositionGeometry.calculate(
        contentBounds: Rect.fromLTWH(
          sidebarWidth + LiveLayoutMetrics.outerPadding,
          bodyTop,
          testCase.availableWidth,
          contentHeight,
        ),
      );
      _expectRect(tester, find.byKey(_playerKey), expected.playerRect);
      expect(expected.playerRect.top, headerRect.bottom);
      _expectInside(headerRect, _rectFor(tester, find.byType(TextField)));
      expect(find.byKey(_playerKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('optical lift moves only the search carrier', (tester) async {
    const availableWidth = 1200.0;
    final sidebarWidth = LiveLayoutMetrics.sidebarWidthFor(expanded: false);
    final totalWidth =
        sidebarWidth + LiveLayoutMetrics.outerPadding * 2 + availableWidth;
    await pumpShell(tester, size: Size(totalWidth, 800), immersive: false);

    final placement = LiveHeaderPlacementMetrics.resolve(
      headerHeight: LiveLayoutMetrics.headerBlockHeight,
    );
    final titleRect = _rectFor(tester, find.byKey(ShellCommandArea.titleKey));
    final searchRect = _rectFor(tester, find.byKey(ShellCommandArea.searchKey));
    expect(titleRect.top, LiveLayoutMetrics.outerPadding);
    expect(searchRect.top, placement.top);
    expect(searchRect.top, lessThan(titleRect.top));
    expect(
      tester
          .widget<Text>(find.byKey(ShellCommandArea.supportingTextKey))
          .maxLines,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps the compact sender-list trigger available at 843x808 and 200%',
    (tester) async {
      await pumpShell(
        tester,
        size: const Size(843, 808),
        immersive: false,
        textScaleFactor: 2,
      );

      expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
      expect(find.byType(ChannelListPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact sender-list trigger remains available at default scale',
    (tester) async {
      await pumpShell(tester, size: const Size(843, 808), immersive: false);

      expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
      expect(find.byType(ChannelListPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category edge action remains available below the three-pane breakpoint',
    (tester) async {
      const availableWidth = 1199.0;
      final totalWidth =
          LiveLayoutMetrics.sidebarWidthFor(expanded: false) +
          LiveLayoutMetrics.outerPadding * 2 +
          availableWidth;
      await pumpShell(
        tester,
        size: Size(totalWidth, 704),
        immersive: false,
        withCategories: true,
      );

      expect(find.byTooltip('Kategorien anzeigen'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('live-category-edge-handle')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Kategorien anzeigen'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveCategorySidebar), findsOneWidget);
      expect(find.byTooltip('Kategorien einklappen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact sender-list trigger remains available with a short body',
    (tester) async {
      const availableWidth = 719.0;
      const textScaleFactor = 2.0;
      const contentHeight = 350.0;
      final headerLayout = LiveHeaderLayoutMetrics.resolve(
        availableWidth: availableWidth,
        textScaleFactor: textScaleFactor,
      );
      final bodyTop = LiveLayoutMetrics.headerTopOffset(
        headerHeight: headerLayout.height,
      );

      await pumpShell(
        tester,
        size: Size(
          LiveLayoutMetrics.sidebarWidthFor(expanded: false) +
              (LiveLayoutMetrics.outerPadding * 2) +
              availableWidth,
          bodyTop + contentHeight + LiveLayoutMetrics.outerPadding,
        ),
        immersive: false,
        textScaleFactor: textScaleFactor,
      );

      expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
      expect(find.byType(ChannelListPanel), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sender list collapse and expand stay overflow-free during animation',
    (tester) async {
      await pumpShell(tester, size: const Size(1348, 704), immersive: false);

      expect(find.byTooltip('Senderliste einklappen'), findsOneWidget);
      await tester.tap(find.byTooltip('Senderliste einklappen'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.takeException(), isNull);
      await tester.pump(LiveTabShell.layoutTransitionDuration);
      expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Senderliste anzeigen'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.takeException(), isNull);
      await tester.pump(LiveTabShell.layoutTransitionDuration);
      expect(find.byTooltip('Senderliste einklappen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category open action remains available when sender rail is collapsed',
    (tester) async {
      await pumpShell(
        tester,
        size: const Size(1348, 704),
        immersive: false,
        withCategories: true,
      );

      expect(find.byTooltip('Kategorien einklappen'), findsOneWidget);
      await tester.tap(find.byTooltip('Kategorien einklappen'));
      await tester.pump(LiveTabShell.layoutTransitionDuration);
      expect(find.byTooltip('Kategorien anzeigen'), findsOneWidget);

      await tester.tap(find.byTooltip('Senderliste einklappen'));
      await tester.pump(LiveTabShell.layoutTransitionDuration);
      expect(find.byType(ChannelListPanel), findsNothing);
      expect(find.byTooltip('Kategorien anzeigen'), findsOneWidget);
      expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pane edge handles follow all four pane states and seams', (
    tester,
  ) async {
    const size = Size(1348, 704);
    final sidebarWidth = LiveLayoutMetrics.sidebarWidthFor(expanded: false);
    final availableWidth =
        size.width - sidebarWidth - (LiveLayoutMetrics.outerPadding * 2);
    final headerLayout = LiveHeaderLayoutMetrics.resolve(
      availableWidth: availableWidth,
      textScaleFactor: 1,
    );
    final placement = LiveHeaderPlacementMetrics.resolve(
      headerHeight: headerLayout.height,
    );
    final bounds = Rect.fromLTWH(
      sidebarWidth + LiveLayoutMetrics.outerPadding,
      placement.bodyTop,
      availableWidth,
      size.height - placement.bodyTop - LiveLayoutMetrics.outerPadding,
    );

    Future<void> pumpTransition() async {
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.takeException(), isNull);
    }

    void expectHandleAt(Key key, Offset center) {
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(
        rect.size,
        const Size(M3PaneEdgeHandle.hitWidth, M3PaneEdgeHandle.hitHeight),
      );
      expect(rect.center.dx, closeTo(center.dx, 0.1));
      expect(rect.center.dy, closeTo(center.dy, 0.1));
    }

    void expectSeams({
      required bool categoryExpanded,
      required bool senderExpanded,
    }) {
      final composition = LiveCompositionGeometry.calculate(
        contentBounds: bounds,
        channelListExpanded: senderExpanded,
        categoryPanelExpanded: categoryExpanded,
      );
      final channelRect = composition.channelListRect!;
      final categoryRect = composition.categoryRect;
      final categoryCenterX = categoryRect == null
          ? channelRect.left
          : (categoryRect.right + channelRect.left) / 2;
      expectHandleAt(
        const ValueKey('live-category-edge-handle'),
        Offset(categoryCenterX, channelRect.center.dy),
      );
      expectHandleAt(
        const ValueKey('live-channel-edge-handle'),
        Offset(
          (channelRect.right + composition.playerRect.left) / 2,
          composition.playerRect.center.dy,
        ),
      );
    }

    await pumpShell(tester, size: size, immersive: false, withCategories: true);

    expect(find.byType(M3PaneEdgeHandle), findsNWidgets(2));
    expect(find.byTooltip('Kategorien einklappen'), findsOneWidget);
    expect(find.byTooltip('Senderliste einklappen'), findsOneWidget);
    expectSeams(categoryExpanded: true, senderExpanded: true);
    expect(
      find.descendant(
        of: find.byType(ChannelListPanel),
        matching: find.byType(M3PaneToggleButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(LiveCategorySidebar),
        matching: find.byType(M3PaneToggleButton),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Kategorien einklappen'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 140));
    final transitionOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('live-category-pane-opacity')),
    );
    expect(transitionOpacity.opacity, inExclusiveRange(0, 1));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 140));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('live-category-pane-opacity')),
          )
          .opacity,
      0,
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Kategorien anzeigen'), findsOneWidget);
    expect(find.byTooltip('Senderliste einklappen'), findsOneWidget);
    expectSeams(categoryExpanded: false, senderExpanded: true);

    await tester.tap(find.byTooltip('Senderliste einklappen'));
    await pumpTransition();
    expect(find.byTooltip('Kategorien anzeigen'), findsOneWidget);
    expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
    expectSeams(categoryExpanded: false, senderExpanded: false);

    await tester.tap(find.byTooltip('Kategorien anzeigen'));
    await pumpTransition();
    expect(find.byTooltip('Kategorien einklappen'), findsOneWidget);
    expect(find.byTooltip('Senderliste anzeigen'), findsOneWidget);
    expectSeams(categoryExpanded: true, senderExpanded: false);

    await tester.tap(find.byTooltip('Senderliste anzeigen'));
    await pumpTransition();
    expect(find.byTooltip('Kategorien einklappen'), findsOneWidget);
    expect(find.byTooltip('Senderliste einklappen'), findsOneWidget);
    expectSeams(categoryExpanded: true, senderExpanded: true);
    expect(find.byKey(_playerKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive composition mounts only the full-size player', (
    tester,
  ) async {
    const size = Size(1280, 720);
    await pumpShell(tester, size: size, immersive: true);

    _expectRect(tester, find.byKey(_playerKey), Offset.zero & size);
    expect(find.byKey(_playerKey), findsOneWidget);
    expect(find.byType(ChannelListPanel), findsNothing);
    expect(find.byType(LiveCategorySidebar), findsNothing);
    expect(find.byType(ShellSidebar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final _playerKey = GlobalKey();

void _expectRect(WidgetTester tester, Finder finder, Rect expected) {
  final renderBox = tester.renderObject<RenderBox>(finder);
  expect(renderBox.localToGlobal(Offset.zero), expected.topLeft);
  expect(renderBox.size, expected.size);
}

Rect _rectFor(WidgetTester tester, Finder finder) {
  final renderBox = tester.renderObject<RenderBox>(finder);
  return renderBox.localToGlobal(Offset.zero) & renderBox.size;
}

void _expectInside(Rect outer, Rect inner) {
  expect(inner.left, greaterThanOrEqualTo(outer.left));
  expect(inner.top, greaterThanOrEqualTo(outer.top));
  expect(inner.right, lessThanOrEqualTo(outer.right));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom));
}
