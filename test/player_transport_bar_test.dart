import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_providers.dart';
import 'package:m3uxtream_player/features/player/widgets/player_transport_bar.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';

class _TestBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

class _TestLiveBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 5;
}

class _TestPlayerNotifier extends PlayerNotifier {
  _TestPlayerNotifier(this.initialState);

  final PlayerState initialState;

  @override
  Future<PlayerState> build() async => initialState;
}

class _FakePlayer extends Fake implements Player {}

ProviderContainer _createTestContainer({
  required Channel channel,
  required PlayerState playerState,
  required PlayerBufferSecondsNotifier Function() createBufferNotifier,
}) {
  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWith(
        (ref) =>
            throw StateError('Transport-bar tests must not open the database'),
      ),
      currentProgramTitleForSelectedChannelProvider.overrideWith((ref) => null),
      selectedChannelProvider.overrideWith((ref) => channel),
      playerBufferSecondsProvider.overrideWith(createBufferNotifier),
      playerNotifierProvider.overrideWith(
        () => _TestPlayerNotifier(playerState),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders a static live buffer bar when live startup buffer is off',
    (tester) async {
      final player = _FakePlayer();

      const liveChannel = Channel(
        id: 1,
        playlistId: 1,
        name: 'Live',
        streamUrl: 'https://example.com/live.m3u8',
        isFavorite: false,
        isWatchLater: false,
        channelType: 'live',
      );

      final playerState = PlayerState(
        player: player,
        isPlaying: false,
        volume: 0.5,
        isBuffering: false,
        isLiveStartupBuffering: false,
      );

      final container = _createTestContainer(
        channel: liveChannel,
        playerState: playerState,
        createBufferNotifier: _TestBufferSecondsNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.highContrastDarkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 720,
                  child: PlayerTransportBar(
                    onTogglePlay: _noop,
                    onStop: _noop,
                    onVolumeChangeEnd: _noopVolume,
                    onToggleMute: _noop,
                    onToggleFullscreen: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 50; i++) {
        if (container.read(playerBufferSecondsProvider).valueOrNull == 0) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(indicator.value, isNotNull);
      expect(indicator.value, 0.0);

      final colors = AppTheme.highContrastDarkTheme.colorScheme;
      expect(
        tester.widget<AppSurface>(find.byType(AppSurface)).level,
        AppSurfaceLevel.high,
      );
      final playButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Play'),
          matching: find.byType(IconButton),
        ),
      );
      final muteButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Mute'),
          matching: find.byType(IconButton),
        ),
      );
      expect(playButton.style?.shape?.resolve({}), isA<CircleBorder>());
      expect(playButton.style?.side?.resolve({}), isNull);
      expect(playButton.style?.backgroundColor?.resolve({}), colors.primary);
      expect(muteButton.style?.shape?.resolve({}), isA<CircleBorder>());
      expect(muteButton.style?.side?.resolve({}), isNull);
      expect(
        muteButton.style?.backgroundColor?.resolve({}),
        colors.secondaryContainer,
      );
      expect(indicator.backgroundColor, colors.surfaceContainerHighest);

      final transportRect = tester.getRect(find.byType(PlayerTransportBar));
      final volumeRect = tester.getRect(find.byTooltip('Mute'));
      final playRect = tester.getRect(find.byTooltip('Play'));
      final audioRect = tester.getRect(
        find.byTooltip('Keine Audio-Spuren erkannt'),
      );
      final fullscreenRect = tester.getRect(find.byTooltip('Fullscreen'));
      expect(volumeRect.center.dx, lessThan(playRect.center.dx));
      expect(playRect.center.dx, lessThan(audioRect.center.dx));
      expect(audioRect.center.dx, lessThan(fullscreenRect.center.dx));
      expect(playRect.center.dx, closeTo(transportRect.center.dx, 36));

      final slider = tester.widget<M3ExpressiveSlider>(
        find.byType(M3ExpressiveSlider),
      );
      expect(slider.value, 0.5);
      expect(slider.semanticFormatter?.call(0.5), 'Lautstärke 50 Prozent');
    },
  );

  testWidgets(
    'renders startup buffering text while live startup buffer is active',
    (tester) async {
      final player = _FakePlayer();

      const liveChannel = Channel(
        id: 1,
        playlistId: 1,
        name: 'Live',
        streamUrl: 'https://example.com/live.m3u8',
        isFavorite: false,
        isWatchLater: false,
        channelType: 'live',
      );

      final playerState = PlayerState(
        player: player,
        isPlaying: false,
        volume: 0.5,
        isBuffering: true,
        isLiveStartupBuffering: true,
      );

      final container = _createTestContainer(
        channel: liveChannel,
        playerState: playerState,
        createBufferNotifier: _TestLiveBufferSecondsNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.highContrastDarkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 720,
                  child: PlayerTransportBar(
                    onTogglePlay: _noop,
                    onStop: _noop,
                    onVolumeChangeEnd: _noopVolume,
                    onToggleMute: _noop,
                    onToggleFullscreen: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.textContaining('Startpuffer wird aufgebaut'), findsOneWidget);
      expect(find.textContaining('Starte bei'), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(
        indicator.color,
        AppTheme.highContrastDarkTheme.extension<AppStatusColors>()!.info,
      );
    },
  );

  testWidgets(
    'renders VOD Expressive scrubber with buffer and seek callbacks',
    (tester) async {
      final seeks = <Duration>[];
      final volumeChanges = <double>[];
      const vodChannel = Channel(
        id: 1,
        playlistId: 1,
        name: 'Movie',
        streamUrl: 'https://example.com/movie.mp4',
        isFavorite: false,
        isWatchLater: false,
        channelType: 'vod',
      );
      final container = _createTestContainer(
        channel: vodChannel,
        playerState: PlayerState(
          player: _FakePlayer(),
          isPlaying: false,
          volume: 0.5,
          position: const Duration(minutes: 2),
          duration: const Duration(minutes: 10),
          vodForwardBufferMs: 90 * 1000,
        ),
        createBufferNotifier: _TestBufferSecondsNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SizedBox(
                width: 720,
                child: PlayerTransportBar(
                  onTogglePlay: _noop,
                  onStop: _noop,
                  onVolumeChanged: volumeChanges.add,
                  onVolumeChangeEnd: _noopVolume,
                  onToggleMute: _noop,
                  onSeek: seeks.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final sliders = find.byType(M3ExpressiveSlider);
      expect(sliders, findsNWidgets(2));
      final scrubber = tester.widget<M3ExpressiveSlider>(sliders.first);
      expect(scrubber.size, M3ExpressiveSliderSize.xs);
      expect(scrubber.max, 600000);
      expect(scrubber.bufferedValue, 210000);

      final scrubRect = tester.getRect(sliders.first);
      await tester.tapAt(
        Offset(scrubRect.left + scrubRect.width * 0.8, scrubRect.center.dy),
      );
      await tester.pump();
      expect(seeks, isNotEmpty);

      final volumeRect = tester.getRect(find.byType(M3ExpressiveSlider).last);
      await tester.tapAt(
        Offset(volumeRect.left + volumeRect.width * 0.7, volumeRect.center.dy),
      );
      await tester.pump();
      expect(volumeChanges, isNotEmpty);
    },
  );

  testWidgets('translucent transport uses an alpha tonal surface', (
    tester,
  ) async {
    final container = _createTestContainer(
      channel: const Channel(
        id: 1,
        playlistId: 1,
        name: 'Live',
        streamUrl: 'https://example.com/live.m3u8',
        isFavorite: false,
        isWatchLater: false,
        channelType: 'live',
      ),
      playerState: PlayerState(
        player: _FakePlayer(),
        isPlaying: false,
        volume: 0.5,
        isBuffering: false,
        isLiveStartupBuffering: false,
      ),
      createBufferNotifier: _TestBufferSecondsNotifier.new,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: 720,
              child: PlayerTransportBar(
                translucent: true,
                onTogglePlay: _noop,
                onStop: _noop,
                onVolumeChangeEnd: _noopVolume,
                onToggleMute: _noop,
                onToggleFullscreen: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final surface = tester.widget<AppSurface>(find.byType(AppSurface));
    expect(
      surface.surfaceColor,
      AppTheme.darkTheme.colorScheme.surfaceContainerHigh.withValues(
        alpha: 0.78,
      ),
    );
  });

  testWidgets(
    'stays within a compact height while live startup buffer is active',
    (tester) async {
      final player = _FakePlayer();

      const liveChannel = Channel(
        id: 1,
        playlistId: 1,
        name: 'Live',
        streamUrl: 'https://example.com/live.m3u8',
        isFavorite: false,
        isWatchLater: false,
        channelType: 'live',
      );

      final playerState = PlayerState(
        player: player,
        isPlaying: false,
        volume: 0.5,
        isBuffering: true,
        isLiveStartupBuffering: true,
      );

      final container = _createTestContainer(
        channel: liveChannel,
        playerState: playerState,
        createBufferNotifier: _TestLiveBufferSecondsNotifier.new,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.highContrastDarkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 720,
                  height: 124,
                  child: PlayerTransportBar(
                    onTogglePlay: _noop,
                    onStop: _noop,
                    onVolumeChangeEnd: _noopVolume,
                    onToggleMute: _noop,
                    onToggleFullscreen: _noop,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Startpuffer wird aufgebaut'), findsOneWidget);
    },
  );

  testWidgets('renders a disabled audio track button when no tracks exist', (
    tester,
  ) async {
    final player = _FakePlayer();

    const liveChannel = Channel(
      id: 1,
      playlistId: 1,
      name: 'Live',
      streamUrl: 'https://example.com/live.m3u8',
      isFavorite: false,
      isWatchLater: false,
      channelType: 'live',
    );

    final playerState = PlayerState(
      player: player,
      isPlaying: false,
      volume: 0.5,
      isBuffering: false,
      isLiveStartupBuffering: false,
      audioTracks: const [],
      selectedAudioTrackId: null,
    );

    final container = _createTestContainer(
      channel: liveChannel,
      playerState: playerState,
      createBufferNotifier: _TestBufferSecondsNotifier.new,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.highContrastDarkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 720,
                child: PlayerTransportBar(
                  onTogglePlay: _noop,
                  onStop: _noop,
                  onVolumeChangeEnd: _noopVolume,
                  onToggleMute: _noop,
                  onToggleFullscreen: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final button = tester.widget<PopupMenuButton<String>>(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton<String>),
    );

    expect(button.enabled, isFalse);
    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(button.color, colors.surfaceContainerHigh);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.audiotrack_rounded)).color,
      colors.onSurface.withValues(alpha: 0.38),
    );
  });
}

void _noop() {}

void _noopVolume(double _) {}
