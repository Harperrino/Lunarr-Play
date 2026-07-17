import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

void main() {
  group('LiveStreamUrl.isExtensionlessContinuousLiveUrl', () {
    test('detects extensionless Xtream/Dispatcharr live URLs', () {
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'http://iptv.example.com/live/u/p/123',
        ),
        isTrue,
      );
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'http://iptv.example.com/live/u/p/123?token=abc',
        ),
        isTrue,
      );
    });

    test('rejects .ts and .m3u8 URLs', () {
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'http://iptv.example.com/live/u/p/123.ts',
        ),
        isFalse,
      );
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'http://iptv.example.com/live/u/p/123.m3u8',
        ),
        isFalse,
      );
    });

    test('rejects HLS-hinted URLs', () {
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'http://iptv.example.com/live/u/p/123?output=m3u8',
        ),
        isFalse,
      );
    });

    test('rejects non-live container URLs', () {
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'https://cdn.example.com/movie.mp4',
        ),
        isFalse,
      );
      expect(
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(
          'https://cdn.example.com/vod/u/p/123',
        ),
        isFalse,
      );
    });
  });

  group('LiveStreamUrl.hasLaterTsCandidate', () {
    late List<StreamingFallbackAttempt> attempts;

    setUp(() {
      attempts = LiveStreamUrl.playbackAttempts(
        'http://iptv.example.com/live/u/p/123',
      );
    });

    test('finds .ts candidate after the extensionless continuous attempt', () {
      final index = attempts.indexWhere(
        (a) =>
            LiveStreamUrl.deliveryFor(a.playbackUrl) ==
                LiveStreamDelivery.continuous &&
            LiveStreamUrl.isExtensionlessContinuousLiveUrl(a.playbackUrl),
      );
      expect(index, greaterThanOrEqualTo(0));
      expect(LiveStreamUrl.hasLaterTsCandidate(attempts, index), isTrue);
    });

    test('returns false once the .ts candidate is current or later', () {
      final tsIndex = attempts.indexWhere(
        (a) =>
            LiveStreamUrl.deliveryFor(a.playbackUrl) ==
            LiveStreamDelivery.tsSegment,
      );
      expect(tsIndex, greaterThan(0));
      expect(LiveStreamUrl.hasLaterTsCandidate(attempts, tsIndex), isFalse);
      expect(
        LiveStreamUrl.hasLaterTsCandidate(attempts, attempts.length - 1),
        isFalse,
      );
    });
  });

  group('deferred HLS probe', () {
    const source = 'http://iptv.example.com/live/u/p/123';

    test('runs only at the transition to header fallbacks', () {
      final attempts = LiveStreamUrl.playbackAttempts(source);
      final boundary = attempts.indexWhere(
        (attempt) => attempt.headerProfile != LiveStreamHeaderProfile.appMpv,
      );

      expect(boundary, greaterThan(0));
      expect(
        shouldRunDeferredHlsProbe(
          autoFallbackEnabled: true,
          alreadyChecked: false,
          sourceDelivery: LiveStreamDelivery.continuous,
          sourceUrl: source,
          attempts: attempts,
          currentIndex: boundary,
        ),
        isTrue,
      );
      expect(
        shouldRunDeferredHlsProbe(
          autoFallbackEnabled: true,
          alreadyChecked: false,
          sourceDelivery: LiveStreamDelivery.continuous,
          sourceUrl: source,
          attempts: attempts,
          currentIndex: boundary - 1,
        ),
        isFalse,
      );
    });

    test('is disabled without fallback or after one probe', () {
      final attempts = LiveStreamUrl.playbackAttempts(source);
      final boundary = attempts.indexWhere(
        (attempt) => attempt.headerProfile != LiveStreamHeaderProfile.appMpv,
      );

      expect(
        shouldRunDeferredHlsProbe(
          autoFallbackEnabled: false,
          alreadyChecked: false,
          sourceDelivery: LiveStreamDelivery.continuous,
          sourceUrl: source,
          attempts: attempts,
          currentIndex: boundary,
        ),
        isFalse,
      );
      expect(
        shouldRunDeferredHlsProbe(
          autoFallbackEnabled: true,
          alreadyChecked: true,
          sourceDelivery: LiveStreamDelivery.continuous,
          sourceUrl: source,
          attempts: attempts,
          currentIndex: boundary,
        ),
        isFalse,
      );
    });

    test('is disabled for explicit and hinted HLS', () {
      for (final sourceUrl in ['$source.m3u8', '$source?output=m3u8']) {
        final attempts = LiveStreamUrl.playbackAttempts(sourceUrl);
        final boundary = attempts.indexWhere(
          (attempt) => attempt.headerProfile != LiveStreamHeaderProfile.appMpv,
        );

        expect(
          shouldRunDeferredHlsProbe(
            autoFallbackEnabled: true,
            alreadyChecked: false,
            sourceDelivery: LiveStreamUrl.deliveryFor(sourceUrl),
            sourceUrl: sourceUrl,
            attempts: attempts,
            currentIndex: boundary,
          ),
          isFalse,
        );
      }
    });

    test('creates one safe app/mpv HLS retry before header fallbacks', () {
      final attempts = LiveStreamUrl.playbackAttempts(
        source,
      ).toList(growable: true);
      final boundary = attempts.indexWhere(
        (attempt) => attempt.headerProfile != LiveStreamHeaderProfile.appMpv,
      );
      final deferred = deferredHlsAttemptFor(source);

      attempts.insert(boundary, deferred);

      expect(deferred.sourceUrl, source);
      expect(deferred.playbackUrl, source);
      expect(deferred.headerProfile, LiveStreamHeaderProfile.appMpv);
      expect(deferred.deliveryType, 'hls');
      expect(deferred.label, 'App/mpv deferred-hls');
      expect(deferred.label, isNot(contains('user/pass')));
      expect(
        attempts[boundary + 1].headerProfile,
        LiveStreamHeaderProfile.vlcLike,
      );
      expect(
        attempts.where((attempt) => attempt.label.contains('deferred-hls')),
        hasLength(1),
      );
    });
  });

  group('shouldQuickSwitchToTsDeliveryCandidate', () {
    const extensionlessContinuousUrl = 'http://iptv.example.com/live/u/p/123';
    final autoNoTracks = <AudioTrack>[AudioTrack.auto(), AudioTrack.no()];

    test('returns true for extensionless continuous + auto/no + later .ts', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          playbackUrl: extensionlessContinuousUrl,
          rawTracks: autoNoTracks,
          selectableTracks: const [],
          hasStreamError: false,
          hasLaterTsCandidate: true,
        ),
        isTrue,
      );
    });

    test('stays on current delivery when selectable tracks appear quickly', () {
      const realTrack = AudioTrack('1', 'Deutsch', 'deu', codec: 'aac');

      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          playbackUrl: extensionlessContinuousUrl,
          rawTracks: [realTrack, AudioTrack.auto()],
          selectableTracks: [realTrack],
          hasStreamError: false,
          hasLaterTsCandidate: true,
        ),
        isFalse,
      );
    });

    test('is disabled for VOD/Series', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: true,
          delivery: LiveStreamDelivery.continuous,
          playbackUrl: extensionlessContinuousUrl,
          rawTracks: autoNoTracks,
          selectableTracks: const [],
          hasStreamError: false,
          hasLaterTsCandidate: true,
        ),
        isFalse,
      );
    });

    test('is disabled for HLS', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.hls,
          playbackUrl: 'http://iptv.example.com/live/u/p/123.m3u8',
          rawTracks: autoNoTracks,
          selectableTracks: const [],
          hasStreamError: false,
          hasLaterTsCandidate: true,
        ),
        isFalse,
      );
    });

    test('is disabled for .ts delivery itself', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.tsSegment,
          playbackUrl: 'http://iptv.example.com/live/u/p/123.ts',
          rawTracks: autoNoTracks,
          selectableTracks: const [],
          hasStreamError: false,
          hasLaterTsCandidate: false,
        ),
        isFalse,
      );
    });

    test('keeps late-audio wait when no .ts alternative exists', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          playbackUrl: extensionlessContinuousUrl,
          rawTracks: autoNoTracks,
          selectableTracks: const [],
          hasStreamError: false,
          hasLaterTsCandidate: false,
        ),
        isFalse,
      );
    });

    test('keeps late-audio wait when raw tracks are empty', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          playbackUrl: extensionlessContinuousUrl,
          rawTracks: const [],
          selectableTracks: const [],
          hasStreamError: false,
          hasLaterTsCandidate: true,
        ),
        isFalse,
      );
    });

    test('does not quick-switch on real stream errors', () {
      expect(
        shouldQuickSwitchToTsDeliveryCandidate(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          playbackUrl: extensionlessContinuousUrl,
          rawTracks: autoNoTracks,
          selectableTracks: const [],
          hasStreamError: true,
          hasLaterTsCandidate: true,
        ),
        isFalse,
      );
    });

    test(
      'quick-switch leaves final release to the later .ts candidate',
      () async {
        final attempts = LiveStreamUrl.playbackAttempts(
          extensionlessContinuousUrl,
        );
        final extensionlessIndex = attempts.indexWhere(
          (attempt) =>
              LiveStreamUrl.deliveryFor(attempt.playbackUrl) ==
                  LiveStreamDelivery.continuous &&
              LiveStreamUrl.isExtensionlessContinuousLiveUrl(
                attempt.playbackUrl,
              ),
        );
        final tsIndex = attempts.indexWhere(
          (attempt) =>
              LiveStreamUrl.deliveryFor(attempt.playbackUrl) ==
              LiveStreamDelivery.tsSegment,
        );

        expect(extensionlessIndex, greaterThanOrEqualTo(0));
        expect(tsIndex, greaterThan(extensionlessIndex));

        final extensionlessAttempt = attempts[extensionlessIndex];
        final tsAttempt = attempts[tsIndex];

        expect(
          shouldQuickSwitchToTsDeliveryCandidate(
            canSeek: false,
            delivery: LiveStreamDelivery.continuous,
            playbackUrl: extensionlessAttempt.playbackUrl,
            rawTracks: autoNoTracks,
            selectableTracks: const [],
            hasStreamError: false,
            hasLaterTsCandidate: LiveStreamUrl.hasLaterTsCandidate(
              attempts,
              extensionlessIndex,
            ),
          ),
          isTrue,
        );

        final events = <String>[];
        final result = await finalizePreparedLiveCandidatePlayback(
          shouldAutoSelectAudioTrack: false,
          shouldEvaluateAudioDecode: false,
          applyBestTrack: () async {
            events.add('apply');
          },
          classifyDecodedAudio: () async {
            events.add('classify');
            return LiveAudioDecodeDecision.confirmed;
          },
          releasePlayback: (_) async {
            events.add('release:${tsAttempt.playbackUrl}');
            return LivePlaybackFinalizationResult.released;
          },
        );

        expect(result, LivePlaybackFinalizationResult.released);
        expect(events, ['release:${tsAttempt.playbackUrl}']);
        expect(
          events.contains('release:${extensionlessAttempt.playbackUrl}'),
          isFalse,
        );
      },
    );
  });
}
