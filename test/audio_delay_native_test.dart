@Tags(['native'])
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/services/audio_delay_session.dart';

import 'helpers/media_kit_test_init.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final library = Platform.environment['LUNARR_MPV_LIBRARY'];
    if (library == null) {
      ensureMediaKitForTests();
    } else {
      MediaKit.ensureInitialized(libmpv: library);
    }
  });

  test('real media_kit accepts both offset limits and reset', () async {
    final player = Player();
    addTearDown(player.dispose);
    final session = AudioDelaySession(
      apply: (value) => applyNativeAudioDelay(player, value),
    );
    addTearDown(session.dispose);
    await session.beginPlayback('first');
    for (final value in [-60000, -5000, 5000, 60000, 0]) {
      await session.setMilliseconds(value);
      expect(session.value, value);
      final native = player.platform as NativePlayer;
      expect(
        double.parse(await native.getProperty('audio-delay')),
        closeTo(value / 1000, 0.0005),
      );
    }
  });

  // Optional playback verification with an 80-second audio/video fixture:
  // ffmpeg -f lavfi -i testsrc2=size=64x64:rate=10 -f lavfi
  //   -i sine=frequency=440:sample_rate=48000 -t 80
  //   -c:v mpeg4 -q:v 10 -c:a pcm_s16le sync.avi
  // Set LUNARR_AUDIO_SYNC_FIXTURE to its absolute path.
  final fixture = Platform.environment['LUNARR_AUDIO_SYNC_FIXTURE'];
  test(
    'real playback advances and delays audio, including changes while playing',
    () async {
      final player = Player();
      addTearDown(player.dispose);
      final native = player.platform as NativePlayer;
      await native.setProperty('vo', 'null');
      await native.setProperty('ao', 'null');
      // media_kit disables video until a VideoController is attached.
      // Headless timing verification still needs a decoded video track.
      await native.setProperty('vid', 'auto');
      await player.open(Media(fixture!));

      Future<void> expectOffset(double seconds) async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        double? measured;
        do {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          final audio = double.tryParse(await native.getProperty('audio-pts'));
          final video = double.tryParse(await native.getProperty('time-pos'));
          if (audio != null && video != null) {
            measured = audio - video;
            if ((measured + seconds).abs() < 0.2) break;
          }
        } while (DateTime.now().isBefore(deadline));
        expect(measured, isNotNull);
        expect(measured!, closeTo(-seconds, 0.2));
      }

      // open() queues loading; wait for decoded audio/video before seeking.
      await expectOffset(0);
      for (final milliseconds in [-60000, 60000, 0]) {
        await applyNativeAudioDelay(player, milliseconds);
        await player.seek(Duration(seconds: milliseconds == 60000 ? 65 : 10));
        await expectOffset(milliseconds / 1000);
      }
      // No seek or reopen: the current playback must respond to adjustments.
      for (final milliseconds in [-500, 500, 0]) {
        await applyNativeAudioDelay(player, milliseconds);
        await expectOffset(milliseconds / 1000);
      }
    },
    skip: fixture == null
        ? 'Set LUNARR_AUDIO_SYNC_FIXTURE for playback verification.'
        : false,
  );

  final ffmpeg = Platform.environment['LUNARR_FFMPEG'];
  test(
    'paced live MPEG-TS recovers from large offsets and both tracks stay smooth',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final producers = <Process>[];
      server.listen((request) async {
        final producer = await Process.start(ffmpeg!, [
          '-hide_banner',
          '-loglevel',
          'error',
          '-re',
          '-stream_loop',
          '-1',
          '-i',
          fixture!,
          '-c:v',
          'mpeg2video',
          '-c:a',
          'aac',
          '-flush_packets',
          '1',
          '-f',
          'mpegts',
          'pipe:1',
        ]);
        producers.add(producer);
        unawaited(producer.stderr.drain<void>());
        request.response.headers.contentType = ContentType('video', 'mp2t');
        try {
          await request.response.addStream(producer.stdout);
          await request.response.close();
        } catch (_) {
          // Player disposal closes the stream before the looping producer ends.
        }
      });
      addTearDown(() async {
        await server.close(force: true);
        for (final producer in producers) {
          producer.kill();
          await producer.exitCode;
        }
      });
      final player = Player();
      addTearDown(player.dispose);
      final native = player.platform as NativePlayer;
      for (final entry in {
        'vo': 'null',
        'ao': 'null',
        'vid': 'auto',
        'cache-pause': 'no',
        'cache-pause-initial': 'no',
        'demuxer-readahead-secs': '3',
        'demuxer-max-back-bytes': '0',
        'demuxer-lavf-format': 'mpegts',
      }.entries) {
        await native.setProperty(entry.key, entry.value);
      }
      await player.open(Media('http://127.0.0.1:${server.port}/live.ts'));

      Future<void> expectSmoothOffset(int milliseconds) async {
        // Live cannot supply future data instantly. Allow one initial realignment,
        // then require continuous advancement of BOTH tracks at the chosen offset.
        final deadline = DateTime.now().add(const Duration(seconds: 50));
        double? previousAudio;
        double? previousVideo;
        var stableSamples = 0;
        do {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          final audio = double.tryParse(await native.getProperty('audio-pts'));
          final video = double.tryParse(await native.getProperty('time-pos'));
          final cacheText = await native.getProperty('demuxer-cache-state');
          final cache = cacheText.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(cacheText) as Map<String, dynamic>;
          if (audio != null &&
              video != null &&
              previousAudio != null &&
              previousVideo != null &&
              cache['underrun'] == false &&
              (audio - video + milliseconds / 1000).abs() < 0.2 &&
              audio - previousAudio > 0.1 &&
              audio - previousAudio < 0.5 &&
              video - previousVideo > 0.1 &&
              video - previousVideo < 0.5) {
            stableSamples++;
          } else {
            stableSamples = 0;
          }
          previousAudio = audio;
          previousVideo = video;
        } while (stableSamples < 20 && DateTime.now().isBefore(deadline));
        expect(
          stableSamples,
          20,
          reason:
              'Both live tracks must advance continuously at $milliseconds ms',
        );
      }

      await expectSmoothOffset(0);
      for (final value in [-15000, 15000, 0]) {
        await applyNativeAudioDelay(player, value);
        await expectSmoothOffset(value);
      }
      expect(await native.getProperty('cache-pause'), 'no');
      expect(
        double.parse(await native.getProperty('demuxer-readahead-secs')),
        3,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: fixture == null || ffmpeg == null
        ? 'Set LUNARR_AUDIO_SYNC_FIXTURE and LUNARR_FFMPEG for paced live verification.'
        : false,
  );
}
