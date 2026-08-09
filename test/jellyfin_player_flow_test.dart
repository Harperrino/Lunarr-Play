library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_media_card.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_screen.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

import 'jellyfin_test_helpers.dart';

/// Taps the interactive poster frame of the card with the given title text.
Future<void> _tapCardPoster(WidgetTester tester, String title) async {
  final card = find.ancestor(
    of: find.text(title).last,
    matching: find.byType(JellyfinMediaCard),
  );
  await tester.tap(
    find.descendant(of: card, matching: find.byType(MediaPosterFrame)),
  );
}

class _FakeVideoController extends Fake implements VideoController {}

class _FlowFakeStream extends Fake implements PlayerStream {
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

class _FlowFakePlayer extends Fake implements Player {
  final _stream = _FlowFakeStream();

  @override
  PlatformPlayer? get platform => null;

  @override
  PlayerStream get stream => _stream;

  @override
  Future<void> open(Playable media, {bool play = true}) async {
    throw StateError('offline');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('item → playback info → direct play → player view → stop', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: _FlowFakePlayer(),
      videoControllerFactory: (_) => _FakeVideoController(),
    );
    addTearDown(() => unawaited(controller.disposeAsync()));

    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinScreen(),
        connection: jellyfinOfflineTestConnection,
        playbackControllerOverride: controller,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Home shelves are loaded (Libraries shelf contains the Movies card).
    expect(find.text('Libraries'), findsOneWidget);
    await _tapCardPoster(tester, 'Movies');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Library grid → movie details.
    expect(find.text('Test Movie'), findsWidgets);
    await _tapCardPoster(tester, 'Test Movie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Details → Play.
    final playButton = find.widgetWithText(FilledButton, 'Play');
    expect(playButton, findsOneWidget);
    await tester.tap(playButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The Jellyfin player surface with its own controls is active.
    expect(find.byType(JellyfinPlayerView), findsOneWidget);
    expect(find.byType(JellyfinPlayerControls), findsOneWidget);

    // Stop returns to the details page and tears the player down.
    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();

    expect(find.byType(JellyfinPlayerView), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
  });
}
