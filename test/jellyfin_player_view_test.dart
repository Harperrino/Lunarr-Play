library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_view.dart';

import 'jellyfin_test_helpers.dart';

const _item = JellyfinItem(id: 'movie-1', name: 'Test Movie', type: 'Movie');
const _firstEpisode = JellyfinItem(
  id: 'episode-2',
  name: 'First Episode',
  type: 'Episode',
  seriesId: 'series-1',
  seriesName: 'Test Series',
  seasonNumber: 1,
  episodeNumber: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('player view renders controls and opens the media on mount', (
    tester,
  ) async {
    final player = _TeardownFakePlayer(openFailure: StateError('offline'));
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
      videoControllerFactory: (_) => _FakeVideoController(),
    );
    addTearDown(() => unawaited(controller.disposeAsync()));

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinPlayerView(
          connection: jellyfinOfflineTestConnection,
          item: _item,
        ),
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(JellyfinPlayerControls), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    expect(find.byIcon(Icons.stop_rounded), findsWidgets);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const ValueKey('jellyfin-seek-slider')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('jellyfin-volume-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('jellyfin-volume-percent')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(player.openedMedia, hasLength(1));
  });

  testWidgets(
    'uses media_kit without standard controls and keeps volume usable',
    (tester) async {
      final player = _TeardownFakePlayer();
      var fullscreenCalls = 0;
      final controller = JellyfinPlayerController(
        connection: jellyfinOfflineTestConnection,
        apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
        player: player,
        videoControllerFactory: (_) => _FakeVideoController(),
      );
      addTearDown(() => unawaited(controller.disposeAsync()));

      controller.state.value = controller.state.value.copyWith(
        initialized: true,
        duration: const Duration(minutes: 90),
      );
      await tester.pumpWidget(
        jellyfinTestHost(
          JellyfinPlayerControls(
            controller: controller,
            onStop: () {},
            onToggleFullscreen: () => fullscreenCalls++,
          ),
          playbackControllerOverride: controller,
        ),
      );

      // This is the media_kit control contract used by JellyfinPlayerView;
      // the view passes this callback to Video instead of rendering defaults.
      final video = Video(
        controller: _FakeVideoController(),
        controls: NoVideoControls,
      );
      expect(video.controls, same(NoVideoControls));
      expect(find.byType(Slider), findsNothing);
      expect(
        find.byKey(const ValueKey('jellyfin-seek-slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('jellyfin-volume-slider')),
        findsOneWidget,
      );

      final volumeSlider = find.byKey(const ValueKey('jellyfin-volume-slider'));
      final volumeRect = tester.getRect(volumeSlider);
      await tester.tapAt(
        Offset(volumeRect.left + volumeRect.width * 0.25, volumeRect.center.dy),
      );
      await tester.pump();
      expect(player.volumeCalls, isNotEmpty);
      expect(player.volumeCalls.last, greaterThan(1.0));
      expect(player.volumeCalls.last, lessThanOrEqualTo(100.0));

      await tester.tap(find.byKey(const ValueKey('jellyfin-mute-button')));
      await tester.pump();
      expect(player.volumeCalls.last, 0.0);
      expect(controller.state.value.muted, isTrue);

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      expect(fullscreenCalls, 1);
    },
  );

  testWidgets('player header back stops playback before leaving', (
    tester,
  ) async {
    final player = _TeardownFakePlayer(openFailure: StateError('offline'));
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
      videoControllerFactory: (_) => _FakeVideoController(),
    );
    addTearDown(() => unawaited(controller.disposeAsync()));

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinPlayerView(
          connection: jellyfinOfflineTestConnection,
          item: _item,
        ),
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    expect(player.stopCount, greaterThanOrEqualTo(1));
  });

  testWidgets('episode player exposes navigation and a closable side overlay', (
    tester,
  ) async {
    final player = _TeardownFakePlayer();
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
      videoControllerFactory: (_) => _FakeVideoController(),
    );
    addTearDown(() => unawaited(controller.disposeAsync()));

    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinPlayerView(
          connection: jellyfinOfflineTestConnection,
          item: _firstEpisode,
        ),
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Previous episode'), findsOneWidget);
    expect(find.byTooltip('Next episode'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('jellyfin-episode-picker-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('jellyfin-episode-picker')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('jellyfin-episode-picker-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('jellyfin-episode-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('jellyfin-player-episode-episode-1')),
      findsOneWidget,
    );
    final currentRow = find.byKey(
      const ValueKey('jellyfin-player-episode-episode-2'),
    );
    expect(tester.widget<InkWell>(currentRow).onTap, isNull);

    await tester.tap(
      find.byKey(const ValueKey('jellyfin-player-episode-episode-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(player.openedMedia, hasLength(2));
    expect(player.openedMedia.last.uri, contains('/Videos/episode-1/'));

    await tester.tap(
      find.byKey(const ValueKey('jellyfin-episode-picker-button')),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('jellyfin-episode-picker')), findsNothing);
    expect(
      find.byKey(const ValueKey('jellyfin-episode-overlay-mounted')),
      findsNothing,
    );
    expect(
      tester
          .widget<Focus>(
            find.byKey(const ValueKey('jellyfin-episode-overlay-button')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('fullscreen player covers the root overlay viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final player = _TeardownFakePlayer(openFailure: StateError('offline'));
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
      videoControllerFactory: (_) => _FakeVideoController(),
    );
    addTearDown(() => unawaited(controller.disposeAsync()));

    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinPlayerView(
          connection: jellyfinOfflineTestConnection,
          item: _item,
        ),
        playbackControllerOverride: controller,
        fullscreen: true,
      ),
    );
    await tester.pump();

    final overlay = find.byKey(const ValueKey('jellyfin-fullscreen-overlay'));
    expect(overlay, findsOneWidget);
    expect(tester.getSize(overlay), const Size(1280, 720));
    expect(
      find.byKey(const ValueKey('jellyfin-fullscreen-placeholder')),
      findsOneWidget,
    );

    final controlsLayer = find.byKey(
      const ValueKey('jellyfin-fullscreen-controls-layer'),
    );
    final headerLayer = find.byKey(
      const ValueKey('jellyfin-fullscreen-header-layer'),
    );
    expect(tester.widget<AnimatedOpacity>(controlsLayer).opacity, 1);
    expect(tester.widget<AnimatedOpacity>(headerLayer).opacity, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedOpacity>(controlsLayer).opacity, 0);
    expect(tester.widget<AnimatedOpacity>(headerLayer).opacity, 0);

    await tester.tapAt(const Offset(640, 360));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(controlsLayer).opacity, 1);
    expect(tester.widget<AnimatedOpacity>(headerLayer).opacity, 1);
  });

  testWidgets('local shortcuts control the jellyfin player instance', (
    tester,
  ) async {
    final player = _TeardownFakePlayer(openFailure: StateError('offline'));
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
      videoControllerFactory: (_) => _FakeVideoController(),
    );
    addTearDown(() => unawaited(controller.disposeAsync()));

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinPlayerView(
          connection: jellyfinOfflineTestConnection,
          item: _item,
        ),
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('autoDispose provider tears the player instance down', (
    tester,
  ) async {
    // A fake player keeps the teardown assertion deterministic; real-player
    // dispose is covered by the native controller tests. The video surface
    // stays unmounted because play() fails fast (error state).
    final player = _TeardownFakePlayer();
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(
        transport: jellyfinHappyTransport(failPlaybackInfo: true),
      ),
      player: player,
      videoControllerFactory: (_) => _FakeVideoController(),
    );

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinPlayerView(
          connection: jellyfinOfflineTestConnection,
          item: _item,
        ),
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      jellyfinTestHost(
        const SizedBox.shrink(),
        playbackControllerOverride: controller,
      ),
    );
    // The unawaited teardown chain spans the fake and real async zones;
    // alternate both until the deterministic dispose has run.
    for (
      var i = 0;
      i < 30 && (player.stopCount == 0 || player.disposeCount == 0);
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }

    expect(player.stopCount, 1);
    expect(player.disposeCount, 1);
  });
}

class _FakeVideoController extends Fake implements VideoController {
  final Player _player = _TeardownFakePlayer();
  final ValueNotifier<PlatformVideoController?> _notifier = ValueNotifier(null);

  @override
  Player get player => _player;

  @override
  ValueNotifier<PlatformVideoController?> get notifier => _notifier;
}

class _TeardownFakeStream extends Fake implements PlayerStream {
  @override
  Stream<bool> get playing => const Stream.empty();

  @override
  Stream<bool> get buffering => const Stream.empty();

  @override
  Stream<bool> get completed => const Stream.empty();

  @override
  Stream<double> get volume => const Stream.empty();

  @override
  Stream<Duration> get duration => const Stream.empty();

  @override
  Stream<Duration> get position => const Stream.empty();

  @override
  Stream<String> get error => const Stream.empty();

  @override
  Stream<List<String>> get subtitle => const Stream.empty();

  @override
  Stream<int?> get width => const Stream.empty();

  @override
  Stream<int?> get height => const Stream.empty();
}

class _TeardownFakePlayer extends Fake implements Player {
  _TeardownFakePlayer({this.openFailure});

  final openedMedia = <Media>[];
  final Object? openFailure;
  int stopCount = 0;
  int disposeCount = 0;
  final volumeCalls = <double>[];

  @override
  PlatformPlayer? get platform => null;

  @override
  PlayerState get state => const PlayerState();

  @override
  PlayerStream get stream => _TeardownFakeStream();

  @override
  Future<void> open(Playable media, {bool play = true}) async {
    openedMedia.add(media as Media);
    final failure = openFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}
