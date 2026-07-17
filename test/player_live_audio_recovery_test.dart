import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

void main() {
  group('shouldWaitForLiveAudioStabilization', () {
    test(
      'fast path skips when audio params present and no risk indicators',
      () {
        expect(
          PlayerNotifier.shouldWaitForLiveAudioStabilization(
            hasDecodedAudioInfo: true,
            audioRecoveryWasNeeded: false,
            liveAudioInitialAutoOnly: false,
            liveAudioHadNoAudioState: false,
            liveAudioTrackSwitchedDuringPrep: false,
            isDirectMpegTs: false,
          ),
          isFalse,
        );
      },
    );

    test(
      'fast path skips when audio params are missing but no risk indicators exist',
      () {
        expect(
          PlayerNotifier.shouldWaitForLiveAudioStabilization(
            hasDecodedAudioInfo: false,
            audioRecoveryWasNeeded: false,
            liveAudioInitialAutoOnly: false,
            liveAudioHadNoAudioState: false,
            liveAudioTrackSwitchedDuringPrep: false,
            isDirectMpegTs: false,
          ),
          isFalse,
        );
      },
    );

    test('waits when audio recovery was needed even if params are present', () {
      expect(
        PlayerNotifier.shouldWaitForLiveAudioStabilization(
          hasDecodedAudioInfo: true,
          audioRecoveryWasNeeded: true,
          liveAudioInitialAutoOnly: false,
          liveAudioHadNoAudioState: false,
          liveAudioTrackSwitchedDuringPrep: false,
          isDirectMpegTs: false,
        ),
        isTrue,
      );
    });

    test('waits when initially only auto/no tracks were exposed', () {
      expect(
        PlayerNotifier.shouldWaitForLiveAudioStabilization(
          hasDecodedAudioInfo: true,
          audioRecoveryWasNeeded: false,
          liveAudioInitialAutoOnly: true,
          liveAudioHadNoAudioState: false,
          liveAudioTrackSwitchedDuringPrep: false,
          isDirectMpegTs: false,
        ),
        isTrue,
      );
    });

    test('waits when track switched during preparation', () {
      expect(
        PlayerNotifier.shouldWaitForLiveAudioStabilization(
          hasDecodedAudioInfo: true,
          audioRecoveryWasNeeded: false,
          liveAudioInitialAutoOnly: false,
          liveAudioHadNoAudioState: false,
          liveAudioTrackSwitchedDuringPrep: true,
          isDirectMpegTs: false,
        ),
        isTrue,
      );
    });

    test('waits when no-audio state was observed', () {
      expect(
        PlayerNotifier.shouldWaitForLiveAudioStabilization(
          hasDecodedAudioInfo: true,
          audioRecoveryWasNeeded: false,
          liveAudioInitialAutoOnly: false,
          liveAudioHadNoAudioState: true,
          liveAudioTrackSwitchedDuringPrep: false,
          isDirectMpegTs: false,
        ),
        isTrue,
      );
    });

    test('waits for direct MPEG-TS when audio params are missing', () {
      expect(
        PlayerNotifier.shouldWaitForLiveAudioStabilization(
          hasDecodedAudioInfo: false,
          audioRecoveryWasNeeded: false,
          liveAudioInitialAutoOnly: false,
          liveAudioHadNoAudioState: false,
          liveAudioTrackSwitchedDuringPrep: false,
          isDirectMpegTs: true,
        ),
        isTrue,
      );
    });

    test(
      'waits when audio recovery was needed and audio params are still missing',
      () {
        expect(
          PlayerNotifier.shouldWaitForLiveAudioStabilization(
            hasDecodedAudioInfo: false,
            audioRecoveryWasNeeded: true,
            liveAudioInitialAutoOnly: false,
            liveAudioHadNoAudioState: false,
            liveAudioTrackSwitchedDuringPrep: false,
            isDirectMpegTs: false,
          ),
          isTrue,
        );
      },
    );

    test(
      'fast path for direct MPEG-TS when audio params are already stable',
      () {
        expect(
          PlayerNotifier.shouldWaitForLiveAudioStabilization(
            hasDecodedAudioInfo: true,
            audioRecoveryWasNeeded: false,
            liveAudioInitialAutoOnly: false,
            liveAudioHadNoAudioState: false,
            liveAudioTrackSwitchedDuringPrep: false,
            isDirectMpegTs: true,
          ),
          isFalse,
        );
      },
    );
  });

  final specialTracks = <AudioTrack>[AudioTrack.auto(), AudioTrack.no()];

  test(
    'retries live MPEG-TS audio exactly once when only auto/no are exposed',
    () {
      expect(
        shouldRetryLiveAudioWithAutoDemuxer(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          recoveryAttempted: false,
          appliedDemuxerLavfFormat: 'mpegts',
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isTrue,
      );

      expect(
        shouldRetryLiveAudioWithAutoDemuxer(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          recoveryAttempted: true,
          appliedDemuxerLavfFormat: 'mpegts',
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isFalse,
      );
    },
  );

  test('auto-demuxer recovery is allowed once per header profile', () {
    final attemptedRecoveryProfiles = <LiveStreamHeaderProfile>{
      LiveStreamHeaderProfile.appMpv,
    };

    bool retryAllowedFor(LiveStreamHeaderProfile profile) {
      return shouldRetryLiveAudioWithAutoDemuxer(
        canSeek: false,
        delivery: LiveStreamDelivery.continuous,
        recoveryAttempted: attemptedRecoveryProfiles.contains(profile),
        appliedDemuxerLavfFormat: 'mpegts',
        rawTracks: specialTracks,
        selectableTracks: const [],
      );
    }

    // appMpv already used its recovery; the other profiles still get theirs.
    expect(retryAllowedFor(LiveStreamHeaderProfile.appMpv), isFalse);
    expect(retryAllowedFor(LiveStreamHeaderProfile.vlcLike), isTrue);
    expect(retryAllowedFor(LiveStreamHeaderProfile.browserLike), isTrue);

    attemptedRecoveryProfiles.add(LiveStreamHeaderProfile.vlcLike);
    expect(retryAllowedFor(LiveStreamHeaderProfile.vlcLike), isFalse);
    expect(retryAllowedFor(LiveStreamHeaderProfile.browserLike), isTrue);
  });

  test(
    'does not retry for VOD, HLS, or when a real audio track already exists',
    () {
      const realTrack = AudioTrack('1', 'Main', 'deu', codec: 'eac3');

      expect(
        shouldRetryLiveAudioWithAutoDemuxer(
          canSeek: true,
          delivery: LiveStreamDelivery.continuous,
          recoveryAttempted: false,
          appliedDemuxerLavfFormat: 'mpegts',
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isFalse,
      );

      expect(
        shouldRetryLiveAudioWithAutoDemuxer(
          canSeek: false,
          delivery: LiveStreamDelivery.hls,
          recoveryAttempted: false,
          appliedDemuxerLavfFormat: '',
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isFalse,
      );

      expect(
        shouldRetryLiveAudioWithAutoDemuxer(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          recoveryAttempted: false,
          appliedDemuxerLavfFormat: 'mpegts',
          rawTracks: [realTrack],
          selectableTracks: [realTrack],
        ),
        isFalse,
      );

      expect(
        shouldRetryLiveAudioWithAutoDemuxer(
          canSeek: false,
          delivery: LiveStreamDelivery.continuous,
          recoveryAttempted: false,
          appliedDemuxerLavfFormat: 'auto',
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isFalse,
      );
    },
  );

  test(
    'audio recovery failure continues live fallback when only auto/no remain',
    () {
      expect(
        shouldContinueLiveFallbackAfterAudioRecovery(
          canSeek: false,
          recoveryAttempted: true,
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isTrue,
      );
    },
  );

  test(
    'audio recovery failure does not continue when a real track is exposed',
    () {
      const realTrack = AudioTrack('1', 'Deutsch', 'deu', codec: 'eac3');

      expect(
        shouldContinueLiveFallbackAfterAudioRecovery(
          canSeek: false,
          recoveryAttempted: true,
          rawTracks: [realTrack],
          selectableTracks: [realTrack],
        ),
        isFalse,
      );
    },
  );

  test(
    'audio recovery failure is ignored before a recovery attempt exists',
    () {
      expect(
        shouldContinueLiveFallbackAfterAudioRecovery(
          canSeek: false,
          recoveryAttempted: false,
          rawTracks: specialTracks,
          selectableTracks: const [],
        ),
        isFalse,
      );
    },
  );

  test('continues fallback for live candidates that expose no real audio', () {
    const realTrack = AudioTrack('1', 'Deutsch', 'deu', codec: 'eac3');

    expect(
      shouldContinueLiveFallbackWhenNoRealAudio(
        canSeek: false,
        rawTracks: specialTracks,
        selectableTracks: const [],
      ),
      isTrue,
    );

    expect(
      shouldContinueLiveFallbackWhenNoRealAudio(
        canSeek: false,
        rawTracks: const [],
        selectableTracks: const [],
      ),
      isTrue,
    );

    expect(
      shouldContinueLiveFallbackWhenNoRealAudio(
        canSeek: false,
        rawTracks: [realTrack],
        selectableTracks: [realTrack],
      ),
      isFalse,
    );

    expect(
      shouldContinueLiveFallbackWhenNoRealAudio(
        canSeek: true,
        rawTracks: specialTracks,
        selectableTracks: const [],
      ),
      isFalse,
    );
  });

  test('reports selected tracks without decoded audio parameters', () {
    const realTrack = AudioTrack('1', 'Deutsch', 'deu', codec: 'eac3');

    expect(
      shouldReportSelectedTrackWithoutDecodedAudio(
        selectableTracks: [realTrack],
        mediaInfo: PlaybackMediaInfo.empty,
      ),
      isTrue,
    );

    expect(
      shouldReportSelectedTrackWithoutDecodedAudio(
        selectableTracks: [realTrack],
        mediaInfo: const PlaybackMediaInfo(audioFormat: 'floatp'),
      ),
      isFalse,
    );

    expect(
      shouldReportSelectedTrackWithoutDecodedAudio(
        selectableTracks: [realTrack],
        mediaInfo: const PlaybackMediaInfo(audioBitrateKbps: 128),
      ),
      isTrue,
    );

    expect(
      shouldReportSelectedTrackWithoutDecodedAudio(
        selectableTracks: const [],
        mediaInfo: PlaybackMediaInfo.empty,
      ),
      isFalse,
    );
  });

  test('continues fallback when selected audio fails to decode', () {
    const realTrack = AudioTrack('1', 'Deutsch', 'deu', codec: 'eac3');

    expect(
      shouldContinueLiveFallbackAfterAudioDecodeFailure(
        selectableTracks: [realTrack],
        mediaInfo: const PlaybackMediaInfo(audioBitrateKbps: 128),
        hadAudioDecodeWarning: true,
      ),
      isTrue,
    );

    expect(
      shouldContinueLiveFallbackAfterAudioDecodeFailure(
        selectableTracks: [realTrack],
        mediaInfo: const PlaybackMediaInfo(audioFormat: 'floatp'),
        hadAudioDecodeWarning: true,
      ),
      isFalse,
    );

    expect(
      shouldContinueLiveFallbackAfterAudioDecodeFailure(
        selectableTracks: [realTrack],
        mediaInfo: PlaybackMediaInfo.empty,
        hadAudioDecodeWarning: false,
      ),
      isFalse,
    );
  });

  test('classifies live audio decode readiness without waiting', () {
    expect(
      classifyLiveAudioDecodeDecision(
        hasRealAudioTrack: true,
        hasDecodedAudioInfo: true,
        hadDecodeWarning: true,
      ),
      LiveAudioDecodeDecision.confirmed,
      reason: 'decoded parameters take precedence over an earlier warning',
    );
    expect(
      classifyLiveAudioDecodeDecision(
        hasRealAudioTrack: true,
        hasDecodedAudioInfo: false,
        hadDecodeWarning: false,
      ),
      LiveAudioDecodeDecision.provisional,
    );
    expect(
      classifyLiveAudioDecodeDecision(
        hasRealAudioTrack: true,
        hasDecodedAudioInfo: false,
        hadDecodeWarning: true,
      ),
      LiveAudioDecodeDecision.failed,
    );
  });

  test(
    'live audio warm-up releases after 200ms of stable parameters',
    () async {
      var elapsed = Duration.zero;
      final result = await waitForLiveAudioWarmup(
        isSessionCurrent: () => true,
        hasDecodedAudioInfo: () => true,
        hasDecodeWarning: () => false,
        elapsedNow: () => elapsed,
        delay: (duration) async {
          elapsed += duration;
        },
      );

      expect(result, LiveAudioWarmupResult.confirmed);
      expect(elapsed, const Duration(milliseconds: 200));
    },
  );

  test(
    'live audio warm-up releases provisionally after at most 600ms',
    () async {
      var elapsed = Duration.zero;
      final result = await waitForLiveAudioWarmup(
        isSessionCurrent: () => true,
        hasDecodedAudioInfo: () => false,
        hasDecodeWarning: () => false,
        elapsedNow: () => elapsed,
        delay: (duration) async {
          elapsed += duration;
        },
      );

      expect(result, LiveAudioWarmupResult.provisional);
      expect(elapsed, const Duration(milliseconds: 600));
    },
  );

  test(
    'decode warning during live audio warm-up fails the candidate',
    () async {
      var elapsed = Duration.zero;
      final result = await waitForLiveAudioWarmup(
        isSessionCurrent: () => true,
        hasDecodedAudioInfo: () => false,
        hasDecodeWarning: () => elapsed >= const Duration(milliseconds: 150),
        elapsedNow: () => elapsed,
        delay: (duration) async {
          elapsed += duration;
        },
      );

      expect(result, LiveAudioWarmupResult.decodeFailed);
      expect(elapsed, const Duration(milliseconds: 150));
    },
  );

  test('session replacement cancels live audio warm-up', () async {
    var elapsed = Duration.zero;
    final result = await waitForLiveAudioWarmup(
      isSessionCurrent: () => elapsed < const Duration(milliseconds: 100),
      hasDecodedAudioInfo: () => false,
      hasDecodeWarning: () => false,
      elapsedNow: () => elapsed,
      delay: (duration) async {
        elapsed += duration;
      },
    );

    expect(result, LiveAudioWarmupResult.staleSession);
    expect(elapsed, const Duration(milliseconds: 100));
  });

  test('finalizes live candidate by selecting audio before release', () async {
    final events = <String>[];

    final result = await finalizePreparedLiveCandidatePlayback(
      shouldAutoSelectAudioTrack: true,
      shouldEvaluateAudioDecode: true,
      applyBestTrack: () async {
        events.add('apply');
      },
      classifyDecodedAudio: () async {
        events.add('classify');
        return LiveAudioDecodeDecision.provisional;
      },
      releasePlayback: (decision) async {
        events.add('release:${decision.name}');
        return LivePlaybackFinalizationResult.released;
      },
    );

    expect(result, LivePlaybackFinalizationResult.released);
    expect(events, ['apply', 'classify', 'release:provisional']);
  });

  test(
    'decode failure blocks release for the current live candidate',
    () async {
      final events = <String>[];

      final result = await finalizePreparedLiveCandidatePlayback(
        shouldAutoSelectAudioTrack: true,
        shouldEvaluateAudioDecode: true,
        applyBestTrack: () async {
          events.add('apply');
        },
        classifyDecodedAudio: () async {
          events.add('classify');
          return LiveAudioDecodeDecision.failed;
        },
        releasePlayback: (_) async {
          events.add('release');
          return LivePlaybackFinalizationResult.released;
        },
      );

      expect(result, LivePlaybackFinalizationResult.decodeFailed);
      expect(events, ['apply', 'classify']);
    },
  );

  test('off mode finalizes live candidate by releasing directly', () async {
    final events = <String>[];

    final result = await finalizePreparedLiveCandidatePlayback(
      shouldAutoSelectAudioTrack: false,
      shouldEvaluateAudioDecode: false,
      applyBestTrack: () async {
        events.add('apply');
      },
      classifyDecodedAudio: () async {
        events.add('classify');
        return LiveAudioDecodeDecision.failed;
      },
      releasePlayback: (decision) async {
        events.add('release:${decision.name}');
        return LivePlaybackFinalizationResult.released;
      },
    );

    expect(result, LivePlaybackFinalizationResult.released);
    expect(events, ['release:confirmed']);
  });

  test('stale release returns staleSession without double play', () async {
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
        events.add('release');
        return LivePlaybackFinalizationResult.staleSession;
      },
    );

    expect(result, LivePlaybackFinalizationResult.staleSession);
    expect(events, ['release']);
  });
}
