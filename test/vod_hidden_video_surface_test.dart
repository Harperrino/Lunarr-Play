@Tags(['native'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/vod/vod_hidden_video_surface.dart';

import 'helpers/media_kit_test_init.dart';
import 'support/fake_media_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  const vodChannel = Channel(
    id: 2,
    playlistId: 1,
    name: 'VOD Movie',
    streamUrl: 'https://example.com/movie.mp4',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'vod',
  );

  ProviderContainer buildContainer({
    required String? playbackUri,
    required Player player,
  }) {
    return ProviderContainer(
      overrides: [
        selectedChannelProvider.overrideWith((ref) => vodChannel),
        playerNotifierProvider.overrideWith(
          () => FixedPlayerNotifier(
            PlayerState(
              player: player,
              playbackUri: playbackUri,
              isPlaying: false,
              volume: 0.5,
              isBuffering: false,
              isLiveStartupBuffering: false,
            ),
          ),
        ),
      ],
    );
  }

  testWidgets(
    'VodHiddenVideoSurface does not mount Video when seekable + player exist '
    'but playbackUri is null',
    (tester) async {
      final container = buildContainer(
        playbackUri: null,
        player: FakeMediaPlayer(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: VodHiddenVideoSurface()),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Video), findsNothing);
    },
  );

  testWidgets(
    'VodHiddenVideoSurface mounts Video when seekable + player + playbackUri are present',
    (tester) async {
      final realPlayer = Player();

      final container = buildContainer(
        playbackUri: 'https://example.com/movie.mp4',
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
            home: Scaffold(body: VodHiddenVideoSurface()),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Video), findsOneWidget);
    },
  );
}
