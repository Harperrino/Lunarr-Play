import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';

import 'jellyfin_test_helpers.dart';

class _ControllableStream extends Fake implements PlayerStream {
  final playingController = StreamController<bool>.broadcast();
  final bufferingController = StreamController<bool>.broadcast();
  final completedController = StreamController<bool>.broadcast();
  final volumeController = StreamController<double>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final errorController = StreamController<String>.broadcast();

  @override
  Stream<bool> get playing => playingController.stream;

  @override
  Stream<bool> get buffering => bufferingController.stream;

  @override
  Stream<bool> get completed => completedController.stream;

  @override
  Stream<double> get volume => volumeController.stream;

  @override
  Stream<Duration> get duration => durationController.stream;

  @override
  Stream<Duration> get position => positionController.stream;

  @override
  Stream<String> get error => errorController.stream;
}

class _ControllablePlayer extends Fake implements Player {
  _ControllablePlayer() {
    _stream = _ControllableStream();
  }

  late final _ControllableStream _stream;
  final openedMedia = <Media>[];
  final seekCalls = <Duration>[];
  final volumeCalls = <double>[];
  int playOrPauseCount = 0;
  int playCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  PlatformPlayer? get platform => null;

  @override
  PlayerStream get stream => _stream;

  @override
  Future<void> open(Playable media, {bool play = true}) async {
    openedMedia.add(media as Media);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeCalls.add(volume);
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> playOrPause() async {
    playOrPauseCount++;
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

const _item = JellyfinItem(
  id: 'movie-1',
  name: 'Test Movie',
  type: 'Movie',
  playbackPositionTicks: 900000000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ControllablePlayer player;
  JellyfinPlayerController? controller;
  var stopperCalls = 0;

  JellyfinPlayerController buildController({bool failPlaybackInfo = false}) {
    final instance = JellyfinPlayerController(
      connection: jellyfinTestConnection,
      apiClient: JellyfinApiClient(
        transport: jellyfinHappyTransport(failPlaybackInfo: failPlaybackInfo),
      ),
      player: player,
      stopExistingPlayback: () async => stopperCalls++,
    );
    controller = instance;
    return instance;
  }

  setUp(() {
    player = _ControllablePlayer();
    stopperCalls = 0;
  });

  tearDown(() async {
    final instance = controller;
    controller = null;
    if (instance != null) {
      await instance.disposeAsync();
    }
  });

  test('play resolves direct play and opens the media with headers', () async {
    final controller = buildController();

    await controller.play(_item);

    expect(stopperCalls, 1);
    expect(player.openedMedia, hasLength(1));
    final media = player.openedMedia.single;
    expect(media.uri, contains('/Videos/movie-1/stream'));
    expect(media.uri, contains('static=true'));
    expect(media.uri, contains('MediaSourceId=ms-1'));
    expect(media.httpHeaders, {'X-Emby-Token': 'token-abc-123'});
    expect(media.start, const Duration(seconds: 90));
    expect(controller.state.value.initialized, isTrue);
    expect(
      controller.state.value.method,
      JellyfinPlaybackMethod.directPlay,
    );
    expect(controller.state.value.title, 'Test Movie');
  });

  test('player streams mirror into the UI state', () async {
    final controller = buildController();
    await controller.play(_item);

    player._stream.playingController.add(true);
    player._stream.bufferingController.add(true);
    player._stream.volumeController.add(0.4);
    player._stream.durationController.add(const Duration(minutes: 90));
    player._stream.positionController.add(const Duration(seconds: 5));
    player._stream.positionController.add(const Duration(seconds: 6));
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.value.playing, isTrue);
    expect(controller.state.value.buffering, isTrue);
    expect(controller.state.value.volume, 0.4);
    expect(controller.state.value.duration, const Duration(minutes: 90));
    expect(controller.state.value.position, const Duration(seconds: 6));
  });

  test('seek clamps to the media duration', () async {
    final controller = buildController();
    await controller.play(_item);
    player._stream.durationController.add(const Duration(minutes: 10));
    await Future<void>.delayed(Duration.zero);

    await controller.seek(const Duration(minutes: 20));
    expect(player.seekCalls.last, const Duration(minutes: 10));
    expect(controller.state.value.position, const Duration(minutes: 10));
  });

  test('seekRelative seeks from the current position', () async {
    final controller = buildController();
    await controller.play(_item);
    player._stream.positionController.add(const Duration(minutes: 1));
    await Future<void>.delayed(Duration.zero);

    await controller.seekRelative(const Duration(seconds: 30));
    expect(player.seekCalls.last, const Duration(minutes: 1, seconds: 30));
  });

  test('volume and mute keep the last non-muted volume', () async {
    final controller = buildController();
    await controller.play(_item);

    await controller.setVolume(0.7);
    await controller.toggleMute();
    expect(controller.state.value.muted, isTrue);
    expect(player.volumeCalls.last, 0.0);

    await controller.toggleMute();
    expect(controller.state.value.muted, isFalse);
    expect(player.volumeCalls.last, 0.7);
    expect(controller.state.value.volume, 0.7);
  });

  test('stop resets playback state without disposing the player', () async {
    final controller = buildController();
    await controller.play(_item);
    player._stream.playingController.add(true);

    await controller.stop();

    expect(player.stopCount, 1);
    expect(controller.state.value.playing, isFalse);
    expect(controller.state.value.initialized, isFalse);
    expect(player.disposeCount, 0);
  });

  test('disposeAsync is idempotent and stops the player exactly once', () async {
    final controller = buildController();
    await controller.play(_item);

    await controller.disposeAsync();
    await controller.disposeAsync();

    expect(player.disposeCount, 1);
    expect(player.stopCount, 1);
    // No state mutation after dispose.
    player._stream.playingController.add(true);
    expect(controller.state.value.playing, isFalse);
  });

  test('a failing playback info request surfaces the error state', () async {
    final controller = buildController(failPlaybackInfo: true);

    await controller.play(_item);

    expect(controller.state.value.error, isTrue);
    expect(controller.state.value.initialized, isFalse);
    expect(player.openedMedia, isEmpty);
  });

  test('missing direct-play source surfaces the error state', () async {
    final transport = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'MediaSources': [
            {'Id': 'ms-t', 'SupportsTranscoding': true},
          ],
        }),
        200,
      ),
    );
    final instance = JellyfinPlayerController(
      connection: jellyfinTestConnection,
      apiClient: JellyfinApiClient(transport: transport),
      player: player,
    );
    controller = instance;

    await instance.play(_item);

    expect(instance.state.value.error, isTrue);
    expect(player.openedMedia, isEmpty);
  });
}
