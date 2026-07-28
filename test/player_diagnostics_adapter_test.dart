import 'package:flutter_test/flutter_test.dart';

import 'package:m3uxtream_player/core/diagnostics/diagnostic_sink.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/features/player/services/player_diagnostics_adapter.dart';

void main() {
  test('adapter keeps source and playback identities separately redacted', () {
    final sink = _RecordingDiagnosticSink();
    final adapter = PlayerDiagnosticsAdapter(readSink: () => sink);
    const attempt = StreamingFallbackAttempt(
      sourceUrl: 'http://host/live/source-user/source-pass/123',
      playbackUrl: 'http://host/live/effective-user/effective-pass/123.ts',
      label: 'TS fallback',
      headerProfile: LiveStreamHeaderProfile.appMpv,
      deliveryType: 'ts',
    );

    adapter.recordStreaming(
      phase: StreamingDiagnosticPhase.started,
      channel: null,
      attempt: attempt,
      mpvError: 'failed http://host/live/effective-user/effective-pass/123.ts',
      diagnosisNote:
          'source http://host/live/source-user/source-pass/123 rejected',
      timestamp: DateTime(2026),
    );

    final event = sink.events.single;
    expect(event.sourceUrlRedacted, isNot(event.playbackUrlRedacted));
    expect(event.sourceUrlRedacted, isNot(contains('source-user')));
    expect(event.sourceUrlRedacted, isNot(contains('source-pass')));
    expect(event.playbackUrlRedacted, isNot(contains('effective-user')));
    expect(event.playbackUrlRedacted, isNot(contains('effective-pass')));
    expect(event.mpvError, isNot(contains('effective-pass')));
    expect(event.diagnosisNote, isNot(contains('source-pass')));
  });

  test('adapter sanitizes text before diagnostic fan-out', () {
    final sink = _RecordingDiagnosticSink();
    final adapter = PlayerDiagnosticsAdapter(readSink: () => sink);

    adapter.logStreamingFailure('failed http://host/live/user/password/123');
    adapter.logAudioWarning(
      'decode failed at http://host/live/user/password/123.ts',
    );

    expect(sink.text, hasLength(2));
    expect(sink.text.join(' '), isNot(contains('password')));
    expect(sink.text[0], startsWith('Streaming:'));
    expect(sink.text[1], startsWith('Audio:'));
  });

  test('adapter exposes sink settings without owning provider state', () {
    final sink = _RecordingDiagnosticSink();
    final adapter = PlayerDiagnosticsAdapter(readSink: () => sink);

    expect(adapter.streamingSettings.autoFallbackEnabled, isTrue);
    expect(adapter.streamingSettings.showOnErrorEnabled, isFalse);
  });
}

final class _RecordingDiagnosticSink implements DiagnosticSink {
  final events = <StreamingDiagnosticEvent>[];
  final text = <String>[];

  @override
  StreamingDiagnosticsSettings get streamingSettings =>
      const StreamingDiagnosticsSettings(
        autoFallbackEnabled: true,
        showOnErrorEnabled: false,
      );

  @override
  void addText(String message) {
    text.add(message);
  }

  @override
  void recordStreaming(StreamingDiagnosticEvent event) {
    events.add(event);
  }
}
