@Tags(['native'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_view.dart';

import 'helpers/media_kit_test_init.dart';
import 'jellyfin_test_helpers.dart';

/// Real media_kit player that additionally counts teardown calls.
class _CountingPlayer extends Player {
  int disposeCount = 0;
  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
    await super.stop();
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await super.dispose();
  }
}

const _item = JellyfinItem(id: 'movie-1', name: 'Test Movie', type: 'Movie');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  testWidgets('player view renders controls and opens the media on mount', (
    tester,
  ) async {
    final player = _CountingPlayer();
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
    );
    addTearDown(() async => controller.disposeAsync());

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinPlayerView(connection: jellyfinOfflineTestConnection, item: _item),
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(JellyfinPlayerControls), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    expect(find.byIcon(Icons.stop_rounded), findsWidgets);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('local shortcuts control the jellyfin player instance', (
    tester,
  ) async {
    final player = _CountingPlayer();
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: player,
    );
    addTearDown(() async => controller.disposeAsync());

    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinPlayerView(connection: jellyfinOfflineTestConnection, item: _item),
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
        JellyfinPlayerView(connection: jellyfinOfflineTestConnection, item: _item),
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
    for (var i = 0;
        i < 30 && (player.stopCount == 0 || player.disposeCount == 0);
        i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }

    expect(player.stopCount, 1);
    expect(player.disposeCount, 1);
  });
}

class _FakeVideoController extends Fake implements VideoController {}

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
}

class _TeardownFakePlayer extends Fake implements Player {
  int stopCount = 0;
  int disposeCount = 0;

  @override
  PlatformPlayer? get platform => null;

  @override
  PlayerStream get stream => _TeardownFakeStream();

  @override
  Future<void> open(Playable media, {bool play = true}) async {}

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}
