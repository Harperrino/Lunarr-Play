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
  final openPlayValues = <bool>[];
  Completer<void>? openStarted;
  Completer<void>? openGate;
  Object? openFailure;
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
    openPlayValues.add(play);
    openStarted?.complete();
    final failure = openFailure;
    if (failure != null) throw failure;
    final gate = openGate;
    if (gate != null) await gate.future;
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

const _secondItem = JellyfinItem(
  id: 'movie-2',
  name: 'Second Movie',
  type: 'Movie',
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
    expect(controller.state.value.method, JellyfinPlaybackMethod.directPlay);
    expect(controller.state.value.title, 'Test Movie');
  });

  test(
    'opens Jellyfin direct stream fallback and forwards its decision flags',
    () async {
      final playbackInfoBodies = <Map<String, dynamic>>[];
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          playbackInfoBodies.add(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          return http.Response(
            jsonEncode({
              'MediaSources': [
                {
                  'Id': 'ms-remux',
                  'Container': 'ts',
                  'SupportsDirectStream': true,
                  'TranscodingUrl': '/Videos/movie-1/master.m3u8',
                },
              ],
              'PlaySessionId': 'ps-remux',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final instance = JellyfinPlayerController(
        connection: jellyfinTestConnection,
        apiClient: JellyfinApiClient(transport: transport),
        player: player,
      );
      controller = instance;

      await instance.play(_item);

      expect(instance.state.value.method, JellyfinPlaybackMethod.directStream);
      expect(player.openedMedia.single.uri, isNot(contains('static=true')));
      expect(
        Uri.parse(player.openedMedia.single.uri).queryParameters['api_key'],
        'token-abc-123',
      );
      expect(playbackInfoBodies, hasLength(2));
      expect(playbackInfoBodies.first['EnableDirectPlay'], isTrue);
      expect(playbackInfoBodies.first['EnableDirectStream'], isFalse);
      expect(playbackInfoBodies.first['EnableTranscoding'], isFalse);
      expect(playbackInfoBodies.last['EnableDirectPlay'], isTrue);
      expect(playbackInfoBodies.last['EnableDirectStream'], isTrue);
      expect(playbackInfoBodies.last['EnableTranscoding'], isTrue);
    },
  );

  test('re-resolves PlaybackInfo when audio and subtitles change', () async {
    final requestBodies = <Map<String, dynamic>>[];
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        requestBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'MediaSources': [
              {
                'Id': 'ms-1',
                'SupportsDirectPlay': true,
                'DefaultAudioStreamIndex': 1,
                'MediaStreams': [
                  {'Index': 0, 'Type': 1, 'Codec': 'h264'},
                  {
                    'Index': 1,
                    'Type': 0,
                    'Codec': 'eac3',
                    'Language': 'deu',
                    'DisplayTitle': 'Deutsch - EAC3 - 5.1',
                  },
                  {
                    'Index': 2,
                    'Type': 0,
                    'Codec': 'aac',
                    'Language': 'eng',
                    'DisplayTitle': 'English - AAC - Stereo',
                  },
                  {
                    'Index': 3,
                    'Type': 2,
                    'Codec': 'subrip',
                    'Language': 'deu',
                    'DisplayTitle': 'Deutsch - SRT',
                  },
                ],
              },
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final instance = JellyfinPlayerController(
      connection: jellyfinTestConnection,
      apiClient: JellyfinApiClient(transport: transport),
      player: player,
    );
    controller = instance;

    await instance.play(_item);
    expect(instance.state.value.audioTracks, hasLength(2));
    expect(instance.state.value.subtitleTracks, hasLength(1));
    expect(instance.state.value.selectedAudioStreamIndex, 1);

    await instance.selectAudioTrack(2);
    expect(requestBodies.last['AudioStreamIndex'], 2);
    expect(player.openedMedia.last.uri, contains('AudioStreamIndex=2'));
    expect(instance.state.value.selectedAudioStreamIndex, 2);

    await instance.selectSubtitleTrack(null);
    expect(requestBodies.last['SubtitleStreamIndex'], -1);
    expect(player.openedMedia.last.uri, contains('SubtitleStreamIndex=-1'));
    expect(instance.state.value.selectedSubtitleStreamIndex, -1);
  });

  test('player streams mirror into the UI state', () async {
    final controller = buildController();
    await controller.play(_item);

    player._stream.playingController.add(true);
    player._stream.bufferingController.add(true);
    player._stream.volumeController.add(40.0);
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
    expect(player.volumeCalls.last, 70.0);
    expect(controller.state.value.muted, isFalse);
    await controller.toggleMute();
    expect(controller.state.value.muted, isTrue);
    expect(player.volumeCalls.last, 0.0);

    await controller.toggleMute();
    expect(controller.state.value.muted, isFalse);
    expect(player.volumeCalls.last, 70.0);
    expect(controller.state.value.volume, 0.7);

    await controller.toggleMute();
    await controller.setVolume(0.3);
    expect(player.volumeCalls.last, 30.0);
    expect(controller.state.value.muted, isFalse);
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

  test(
    'disposeAsync is idempotent and stops the player exactly once',
    () async {
      final controller = buildController();
      await controller.play(_item);

      await controller.disposeAsync();
      await controller.disposeAsync();

      expect(player.disposeCount, 1);
      expect(player.stopCount, 1);
      // No state mutation after dispose.
      player._stream.playingController.add(true);
      expect(controller.state.value.playing, isFalse);
    },
  );

  test(
    'stop waits for a pending open and leaves no initialized playback',
    () async {
      final instance = buildController();
      final openGate = Completer<void>();
      player.openGate = openGate;
      player.openStarted = Completer<void>();

      final playFuture = instance.play(_item);
      await player.openStarted!.future;
      var stopCompleted = false;
      final stopFuture = instance.stop().then((_) => stopCompleted = true);

      await Future<void>.delayed(Duration.zero);
      expect(stopCompleted, isFalse);
      openGate.complete();
      await Future.wait([playFuture, stopFuture]);

      expect(stopCompleted, isTrue);
      expect(player.stopCount, 1);
      expect(instance.state.value.initialized, isFalse);
    },
  );

  test('dispose waits for a pending open before disposing Player B', () async {
    final instance = buildController();
    final openGate = Completer<void>();
    player.openGate = openGate;
    player.openStarted = Completer<void>();

    final playFuture = instance.play(_item);
    await player.openStarted!.future;
    final disposeFuture = instance.disposeAsync();

    await Future<void>.delayed(Duration.zero);
    expect(player.disposeCount, 0);
    openGate.complete();
    await Future.wait([playFuture, disposeFuture]);

    expect(player.stopCount, 1);
    expect(player.disposeCount, 1);
    expect(instance.state.value.initialized, isFalse);
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

  test('stale playback info cannot open after a newer item starts', () async {
    final firstResponse = Completer<http.Response>();
    final secondResponse = Completer<http.Response>();
    final firstRequestSeen = Completer<void>();
    final secondRequestSeen = Completer<void>();
    var playbackRequests = 0;
    final happyHandler = jellyfinHappyHandler();
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        playbackRequests++;
        if (playbackRequests == 1) {
          firstRequestSeen.complete();
          return firstResponse.future;
        }
        secondRequestSeen.complete();
        return secondResponse.future;
      }
      return happyHandler(request);
    });
    final instance = JellyfinPlayerController(
      connection: jellyfinTestConnection,
      apiClient: JellyfinApiClient(transport: transport),
      player: player,
    );
    controller = instance;

    final firstPlay = instance.play(_item);
    await firstRequestSeen.future;
    final secondPlay = instance.play(_secondItem);
    await secondRequestSeen.future;

    firstResponse.complete(
      http.Response(
        jsonEncode({
          'MediaSources': [
            {'Id': 'ms-first', 'SupportsDirectPlay': true},
          ],
          'PlaySessionId': 'ps-first',
        }),
        200,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    secondResponse.complete(
      http.Response(
        jsonEncode({
          'MediaSources': [
            {'Id': 'ms-second', 'SupportsDirectPlay': true},
          ],
          'PlaySessionId': 'ps-second',
        }),
        200,
      ),
    );

    await Future.wait([firstPlay, secondPlay]);

    expect(player.openedMedia, hasLength(1));
    expect(player.openedMedia.single.uri, contains('/Videos/movie-2/stream'));
    expect(instance.state.value.title, 'Second Movie');
  });

  test('dispose invalidates a pending playback request', () async {
    final response = Completer<http.Response>();
    final requestSeen = Completer<void>();
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        requestSeen.complete();
        return response.future;
      }
      return jellyfinHappyHandler()(request);
    });
    final instance = JellyfinPlayerController(
      connection: jellyfinTestConnection,
      apiClient: JellyfinApiClient(transport: transport),
      player: player,
    );
    controller = instance;

    final pendingPlay = instance.play(_item);
    await requestSeen.future;
    await instance.disposeAsync();
    response.complete(
      http.Response(
        jsonEncode({
          'MediaSources': [
            {'Id': 'ms-1', 'SupportsDirectPlay': true},
          ],
        }),
        200,
      ),
    );
    await pendingPlay;

    expect(player.openedMedia, isEmpty);
    expect(player.stopCount, 1);
    expect(player.disposeCount, 1);
  });

  test('uses tracks and defaults from the resolved media source', () async {
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        return http.Response(
          jsonEncode({
            'MediaSources': [
              {
                'Id': 'unusable',
                'MediaStreams': [
                  {'Index': 1, 'Type': 'Audio', 'IsDefault': true},
                ],
              },
              {
                'Id': 'selected',
                'SupportsDirectPlay': true,
                'DefaultAudioStreamIndex': 999,
                'DefaultSubtitleStreamIndex': 888,
                'MediaStreams': [
                  {'Index': 5, 'Type': 'Audio'},
                  {'Index': 7, 'Type': 'Subtitle'},
                ],
              },
            ],
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    final instance = JellyfinPlayerController(
      connection: jellyfinTestConnection,
      apiClient: JellyfinApiClient(transport: transport),
      player: player,
    );
    controller = instance;

    await instance.play(_item);

    expect(instance.state.value.mediaSourceId, 'selected');
    expect(instance.state.value.audioTracks.map((track) => track.index), [5]);
    expect(instance.state.value.subtitleTracks.map((track) => track.index), [
      7,
    ]);
    expect(instance.state.value.selectedAudioStreamIndex, 5);
    expect(instance.state.value.selectedSubtitleStreamIndex, -1);
  });

  test(
    'falls back to response-level tracks when the selected source has none',
    () async {
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/PlaybackInfo')) {
          return http.Response(
            jsonEncode({
              'MediaSources': [
                {'Id': 'selected', 'SupportsDirectPlay': true},
              ],
              'MediaStreams': [
                {'Index': 4, 'Type': 'Audio', 'IsDefault': true},
                {'Index': 6, 'Type': 'Subtitle'},
              ],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final instance = JellyfinPlayerController(
        connection: jellyfinTestConnection,
        apiClient: JellyfinApiClient(transport: transport),
        player: player,
      );
      controller = instance;

      await instance.play(_item);

      expect(instance.state.value.audioTracks.map((track) => track.index), [4]);
      expect(instance.state.value.subtitleTracks.map((track) => track.index), [
        6,
      ]);
      expect(instance.state.value.selectedAudioStreamIndex, 4);
      expect(instance.state.value.selectedSubtitleStreamIndex, -1);
    },
  );

  test(
    'rotates a timed-out paused player and ignores its late completion',
    () async {
      final first = player;
      final second = _ControllablePlayer();
      first.openGate = Completer<void>();
      final instance = JellyfinPlayerController(
        connection: jellyfinTestConnection,
        apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
        player: first,
        playerFactory: () => second,
        playerOpenTimeout: const Duration(milliseconds: 20),
      );
      controller = instance;

      await instance.play(_item);

      expect(instance.state.value.error, isTrue);
      expect(instance.state.value.playerGeneration, 1);
      expect(first.openPlayValues, [false]);
      expect(first.playCount, 0);
      first._stream.playingController.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(instance.state.value.playing, isFalse);
      await instance.stop().timeout(const Duration(milliseconds: 100));

      await instance.play(_secondItem);
      expect(second.openPlayValues, [false]);
      expect(second.playCount, 1);
      expect(instance.state.value.title, 'Second Movie');

      first.openGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(first.playCount, 0);
      expect(first.stopCount, 1);
      expect(first.disposeCount, 1);
    },
  );
}
