import 'package:flutter_test/flutter_test.dart';

import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/features/player/services/player_diagnostics_reporter.dart';
import 'package:m3uxtream_player/features/player/services/player_playback_policies.dart';

void main() {
  group('PlayerStreamErrorPolicy', () {
    test('keeps codec warnings non-fatal and open failures actionable', () {
      expect(
        PlayerStreamErrorPolicy.isNonFatal('Error decoding audio frame'),
        isTrue,
      );
      expect(
        PlayerStreamErrorPolicy.isAudioDecodeWarning(
          'Error decoding audio frame',
        ),
        isTrue,
      );
      expect(
        PlayerStreamErrorPolicy.isOpenError('Failed to open media'),
        isTrue,
      );
      expect(
        PlayerStreamErrorPolicy.isNonFatal('Failed to open media'),
        isFalse,
      );
    });
  });

  group('LiveAudioStabilizationPolicy', () {
    test('uses the stable-track fast path when no risk is present', () {
      expect(
        LiveAudioStabilizationPolicy.shouldWait(
          hasDecodedAudioInfo: true,
          audioRecoveryWasNeeded: false,
          initialAutoOnly: false,
          hadNoAudioState: false,
          trackSwitchedDuringPrep: false,
          isDirectMpegTs: true,
        ),
        isFalse,
      );
      expect(
        LiveAudioStabilizationPolicy.reason(
          hasDecodedAudioInfo: true,
          audioRecoveryWasNeeded: false,
          initialAutoOnly: false,
          hadNoAudioState: false,
          trackSwitchedDuringPrep: false,
          isDirectMpegTs: true,
        ),
        'stable track fast path',
      );
    });

    test('prioritizes recovery as stabilization reason', () {
      expect(
        LiveAudioStabilizationPolicy.shouldWait(
          hasDecodedAudioInfo: false,
          audioRecoveryWasNeeded: true,
          initialAutoOnly: true,
          hadNoAudioState: true,
          trackSwitchedDuringPrep: true,
          isDirectMpegTs: true,
        ),
        isTrue,
      );
      expect(
        LiveAudioStabilizationPolicy.reason(
          hasDecodedAudioInfo: false,
          audioRecoveryWasNeeded: true,
          initialAutoOnly: true,
          hadNoAudioState: true,
          trackSwitchedDuringPrep: true,
          isDirectMpegTs: true,
        ),
        'recovery',
      );
    });
  });

  test('PlayerDiagnosticsReporter redacts URLs and diagnostic text', () {
    const reporter = PlayerDiagnosticsReporter();
    final event = reporter.createStreamingEvent(
      timestamp: DateTime.utc(2026, 7, 17),
      phase: StreamingDiagnosticPhase.failure,
      channel: null,
      attempt: const StreamingFallbackAttempt(
        sourceUrl:
            'http://alice:secret@example.com/live/alice/secret/1?token=abc',
        playbackUrl:
            'http://alice:secret@example.com/live/alice/secret/1?token=abc',
        label: 'test',
        headerProfile: LiveStreamHeaderProfile.appMpv,
        deliveryType: 'continuous',
      ),
      mpvError:
          'Failed http://alice:secret@example.com/live/alice/secret/1?token=abc',
      diagnosisNote:
          'Retry http://alice:secret@example.com/live/alice/secret/1?token=abc',
    );

    final serialized = event.toJson().values.join(' ');
    expect(serialized, contains('example.com'));
    expect(serialized, isNot(contains('secret')));
    expect(serialized, isNot(contains('token=abc')));
  });
}
