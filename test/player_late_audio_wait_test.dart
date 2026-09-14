import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

void main() {
  group('waitForLateLiveAudioTracks', () {
    test('finds selectable track that appears during the wait', () async {
      final trackLists = <Tracks>[
        Tracks(
          video: [],
          audio: [AudioTrack.auto(), AudioTrack.no()],
          subtitle: [],
        ),
        Tracks(
          video: [],
          audio: [AudioTrack.auto(), AudioTrack.no()],
          subtitle: [],
        ),
        Tracks(
          video: [],
          audio: [
            const AudioTrack('1', 'Deutsch', 'de', codec: 'aac'),
            AudioTrack.auto(),
            AudioTrack.no(),
          ],
          subtitle: [],
        ),
      ];
      var index = 0;

      final outcome = await waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.continuous,
        currentTracks: () {
          final tracks = trackLists[index];
          if (index < trackLists.length - 1) index++;
          return tracks;
        },
        isSessionCurrent: () => true,
        hasStreamError: () => false,
        timeout: const Duration(milliseconds: 300),
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(outcome.result, LateAudioWaitResult.tracksFound);
      expect(outcome.selectable.length, 1);
      expect(outcome.selectable.first.id, '1');
    });

    test('times out when no real track appears', () async {
      final tracks = Tracks(
        video: [],
        audio: [AudioTrack.auto(), AudioTrack.no()],
        subtitle: [],
      );

      final outcome = await waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.continuous,
        currentTracks: () => tracks,
        isSessionCurrent: () => true,
        hasStreamError: () => false,
        timeout: const Duration(milliseconds: 150),
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(outcome.result, LateAudioWaitResult.timedOut);
      expect(outcome.selectable, isEmpty);
    });

    test('cancels immediately when session becomes stale', () async {
      final tracks = Tracks(
        video: [],
        audio: [AudioTrack.auto(), AudioTrack.no()],
        subtitle: [],
      );
      var sessionCurrent = true;

      final future = waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.continuous,
        currentTracks: () => tracks,
        isSessionCurrent: () => sessionCurrent,
        hasStreamError: () => false,
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
      );

      // Simulate a zap/stop after one poll cycle.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      sessionCurrent = false;

      final outcome = await future;
      expect(outcome.result, LateAudioWaitResult.cancelled);
      expect(outcome.selectable, isEmpty);
    });

    test('is skipped when a stream error is present', () async {
      final tracks = Tracks(
        video: [],
        audio: [AudioTrack.auto(), AudioTrack.no()],
        subtitle: [],
      );

      final outcome = await waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.continuous,
        currentTracks: () => tracks,
        isSessionCurrent: () => true,
        hasStreamError: () => true,
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(outcome.result, LateAudioWaitResult.skipped);
    });

    test('is skipped for HLS delivery', () async {
      final tracks = Tracks(
        video: [],
        audio: [AudioTrack.auto(), AudioTrack.no()],
        subtitle: [],
      );

      final outcome = await waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.hls,
        currentTracks: () => tracks,
        isSessionCurrent: () => true,
        hasStreamError: () => false,
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(outcome.result, LateAudioWaitResult.skipped);
    });

    test('is skipped when raw tracks are empty', () async {
      const tracks = Tracks(video: [], audio: [], subtitle: []);

      final outcome = await waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.continuous,
        currentTracks: () => tracks,
        isSessionCurrent: () => true,
        hasStreamError: () => false,
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(outcome.result, LateAudioWaitResult.skipped);
    });

    test('is skipped when a real track is already present', () async {
      final tracks = Tracks(
        video: [],
        audio: [
          const AudioTrack('1', 'Deutsch', 'de', codec: 'aac'),
          AudioTrack.auto(),
        ],
        subtitle: [],
      );

      final outcome = await waitForLateLiveAudioTracks(
        delivery: LiveStreamDelivery.continuous,
        currentTracks: () => tracks,
        isSessionCurrent: () => true,
        hasStreamError: () => false,
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
      );

      expect(outcome.result, LateAudioWaitResult.tracksFound);
      expect(outcome.selectable.length, 1);
    });
  });
}
