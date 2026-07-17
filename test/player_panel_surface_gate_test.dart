@Tags(['native', 'golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_providers.dart';
import 'package:m3uxtream_player/features/player/widgets/player_panel.dart';
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

import 'helpers/media_kit_test_init.dart';
import 'support/fake_media_player.dart';

class _TestBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  const liveChannel = Channel(
    id: 1,
    playlistId: 1,
    name: 'Live',
    streamUrl: 'https://example.com/live.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
  );

  ProviderContainer buildContainer({
    required String? playbackUri,
    required Player player,
    bool isBuffering = false,
    bool panelLoading = false,
    String? panelErrorMessage,
  }) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError(
            'Player-panel surface-gate tests must not open the database',
          ),
        ),
        currentProgramTitleForSelectedChannelProvider.overrideWith(
          (ref) => null,
        ),
        selectedChannelProvider.overrideWith((ref) => liveChannel),
        playerBufferSecondsProvider.overrideWith(
          _TestBufferSecondsNotifier.new,
        ),
        playerNotifierProvider.overrideWith(
          () => FixedPlayerNotifier(
            PlayerState(
              player: player,
              playbackUri: playbackUri,
              isPlaying: false,
              volume: 0.5,
              isBuffering: isBuffering,
              isLiveStartupBuffering: false,
            ),
          ),
        ),
        if (panelLoading) playerPanelLoadingProvider.overrideWithValue(true),
        if (panelErrorMessage != null)
          playerPanelErrorMessageProvider.overrideWithValue(panelErrorMessage),
      ],
    );
  }

  testWidgets(
    'PlayerPanel does not mount Video while controller exists but playbackUri is null',
    (tester) async {
      final container = buildContainer(
        playbackUri: null,
        player: FakeMediaPlayer(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: AppColorRoles.darkScheme,
            ),
            home: const Scaffold(
              body: SizedBox(width: 800, height: 600, child: PlayerPanel()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Video), findsNothing);
      expect(find.textContaining('Select a channel to play'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('windowed-player-empty-state')),
        findsOneWidget,
      );
      final stageDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('windowed-player-stage')),
                  )
                  .decoration
              as BoxDecoration;
      expect(stageDecoration.border, isNull);
      await expectLater(
        find.byType(PlayerPanel),
        matchesGoldenFile('goldens/d17_windowed_player_empty.png'),
      );
    },
  );

  testWidgets(
    'PlayerPanel mounts Video when controller and playbackUri are present',
    (tester) async {
      final realPlayer = Player();

      final container = buildContainer(
        playbackUri: 'https://example.com/live.m3u8',
        player: realPlayer,
      );
      addTearDown(() {
        container.dispose();
        realPlayer.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 800, height: 600, child: PlayerPanel()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Video), findsOneWidget);
    },
  );

  testWidgets(
    'PlayerPanel shows preparation overlay when live channel selected, buffering, without playbackUri',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError(
              'Player-panel surface-gate tests must not open the database',
            ),
          ),
          currentProgramTitleForSelectedChannelProvider.overrideWith(
            (ref) => null,
          ),
          selectedChannelProvider.overrideWith((ref) => liveChannel),
          playerBufferSecondsProvider.overrideWith(
            _TestBufferSecondsNotifier.new,
          ),
          playerNotifierProvider.overrideWith(
            () => FixedPlayerNotifier(
              PlayerState(
                player: FakeMediaPlayer(),
                playbackUri: null,
                isPlaying: false,
                volume: 0.5,
                isBuffering: true,
                isLiveStartupBuffering: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 800, height: 600, child: PlayerPanel()),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('Stream wird vorbereitet'), findsOneWidget);
      expect(find.byType(Video), findsNothing);
    },
  );

  testWidgets('PlayerPanel stays overflow-free in a narrow windowed panel', (
    tester,
  ) async {
    final container = buildContainer(
      playbackUri: null,
      player: FakeMediaPlayer(),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 384,
              height: 600,
              child: PlayerPanel(onToggleFullscreen: _noOp),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('windowed loading keeps the level-2 surface and 16:9 stage', (
    tester,
  ) async {
    final container = buildContainer(
      playbackUri: null,
      player: FakeMediaPlayer(),
      panelLoading: true,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 800, height: 600, child: PlayerPanel()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widgetList<AppSurface>(find.byType(AppSurface))
          .any((surface) => surface.elevation == AppElevation.level2),
      isTrue,
    );
    final stage = tester.getSize(
      find.byKey(const ValueKey('windowed-player-stage')),
    );
    expect(stage.width / stage.height, closeTo(16 / 9, 0.01));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PlayerPanel),
      matchesGoldenFile('goldens/d12_windowed_player_loading.png'),
    );
  });

  testWidgets('windowed error keeps the level-2 surface and semantic roles', (
    tester,
  ) async {
    final container = buildContainer(
      playbackUri: null,
      player: FakeMediaPlayer(),
      panelErrorMessage: 'Unable to open stream',
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: AppColorRoles.darkScheme,
          ),
          home: const Scaffold(
            body: SizedBox(width: 800, height: 600, child: PlayerPanel()),
          ),
        ),
      ),
    );
    await tester.pump();

    final colors = AppColorRoles.darkScheme;
    expect(find.text('Unable to open stream'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Unable to open stream')).style?.color,
      colors.onErrorContainer,
    );
    expect(
      tester
          .widgetList<AppSurface>(find.byType(AppSurface))
          .any((surface) => surface.elevation == AppElevation.level2),
      isTrue,
    );
    final stage = tester.getSize(
      find.byKey(const ValueKey('windowed-player-stage')),
    );
    expect(stage.width / stage.height, closeTo(16 / 9, 0.01));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PlayerPanel),
      matchesGoldenFile('goldens/d12_windowed_player_error.png'),
    );
  });

  testWidgets('PlayerPanel neutral presentation surfaces follow theme roles', (
    tester,
  ) async {
    final container = buildContainer(
      playbackUri: null,
      player: FakeMediaPlayer(),
      isBuffering: true,
    );
    addTearDown(container.dispose);

    Future<void> pumpPanel(ThemeData theme) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            key: ValueKey<Color>(theme.colorScheme.onSurfaceVariant),
            theme: theme,
            home: Scaffold(
              body: const SizedBox(
                width: 800,
                height: 600,
                child: PlayerPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> expectRoles(ColorScheme colors) async {
      final header = find.ancestor(
        of: find.text('Live'),
        matching: find.byType(AppSurface),
      );
      expect(header, findsNWidgets(2));
      expect(
        tester
            .widgetList<AppSurface>(find.byType(AppSurface))
            .any((surface) => surface.elevation == AppElevation.level2),
        isTrue,
      );
      expect(
        tester.widget<Text>(find.text('Live')).style?.color,
        colors.onSurfaceVariant,
      );
      expect(
        find.descendant(
          of: header.first,
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );

      expect(find.byType(AppOverlaySurface), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Stream wird vorbereitet')).style?.color,
        colors.onSurface,
      );
      expect(
        tester
            .widget<Text>(find.textContaining('Verbindung wird hergestellt'))
            .style
            ?.color,
        colors.onSurfaceVariant,
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.descendant(
                of: find.byType(AppOverlaySurface),
                matching: find.byType(LinearProgressIndicator),
              ),
            )
            .backgroundColor,
        colors.surfaceContainerLow,
      );
    }

    await pumpPanel(AppTheme.darkTheme);
    await expectRoles(AppTheme.darkTheme.colorScheme);

    await pumpPanel(AppTheme.highContrastDarkTheme);
    await expectRoles(AppTheme.highContrastDarkTheme.colorScheme);
  });
}

void _noOp() {}
