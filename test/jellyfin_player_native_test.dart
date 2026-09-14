@Tags(['native'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';

import 'helpers/media_kit_test_init.dart';
import 'jellyfin_test_helpers.dart';

/// Native smoke for the real media_kit instance.
///
/// Native command futures do not settle reliably inside the fake-async test
/// zone, so commands are fired unawaited and frames are pumped — the same
/// pattern the existing player native tests use. Deterministic dispose
/// assertions live in the fake-player controller tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  testWidgets('a real player survives volume/mute commands and dispose', (
    tester,
  ) async {
    final controller = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: Player(),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    unawaited(controller.setVolume(0.5));
    unawaited(controller.toggleMute());
    unawaited(controller.togglePlayPause());
    await tester.pump(const Duration(milliseconds: 100));

    unawaited(controller.disposeAsync());
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh real player instance works after a full dispose', (
    tester,
  ) async {
    final first = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: Player(),
    );
    await tester.pump();
    unawaited(first.disposeAsync());
    await tester.pump(const Duration(milliseconds: 100));

    final second = JellyfinPlayerController(
      connection: jellyfinOfflineTestConnection,
      apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      player: Player(),
    );
    await tester.pump();
    unawaited(second.setVolume(1.0));
    unawaited(second.disposeAsync());
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
