import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/streaming_diagnostics_providers.dart';

StreamingDiagnosticEvent _event(int index, {bool failed = false}) {
  return StreamingDiagnosticEvent(
    timestamp: DateTime.fromMillisecondsSinceEpoch(index),
    phase: failed
        ? StreamingDiagnosticPhase.failure
        : StreamingDiagnosticPhase.success,
    channelName: 'Channel $index',
    channelId: '$index',
    sourceUrlRedacted: 'source-$index',
    playbackUrlRedacted: 'playback-$index',
    fallbackLabel: 'Attempt $index',
    headerProfile: LiveStreamHeaderProfile.appMpv,
    deliveryType: 'continuous',
    failureKind: failed ? StreamingFailureKind.unknown : null,
    duration: Duration(milliseconds: index),
  );
}

void main() {
  test('keeps only the most recent streaming diagnostics events', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(streamingDiagnosticsProvider.notifier);

    for (var i = 0; i < 130; i++) {
      notifier.record(_event(i, failed: i == 129));
    }

    final snapshot = container.read(streamingDiagnosticsProvider);
    expect(snapshot.events.length, 120);
    expect(snapshot.events.first.timestamp.millisecondsSinceEpoch, 10);
    expect(snapshot.lastFailure?.timestamp.millisecondsSinceEpoch, 129);
  });

  test('can clear diagnostic history', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(streamingDiagnosticsProvider.notifier);
    notifier.record(_event(1, failed: true));
    notifier.clear();

    expect(container.read(streamingDiagnosticsProvider).events, isEmpty);
  });

  test('formats structured live prebuffer diagnostics labels', () {
    expect(StreamingDiagnosticPhase.prebufferStarted.label, 'PREBUFFER START');
    expect(
      StreamingDiagnosticPhase.prebufferReached.label,
      'PREBUFFER REACHED',
    );
    expect(
      StreamingDiagnosticPhase.prebufferTimedOut.label,
      'PREBUFFER TIMEOUT',
    );
    expect(
      StreamingDiagnosticPhase.prebufferCancelled.label,
      'PREBUFFER CANCELLED',
    );

    final event = StreamingDiagnosticEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(1),
      phase: StreamingDiagnosticPhase.prebufferTimedOut,
      channelName: 'Channel',
      channelId: '1',
      sourceUrlRedacted: 'source',
      playbackUrlRedacted: 'playback',
      fallbackLabel: 'Attempt 1',
      headerProfile: LiveStreamHeaderProfile.appMpv,
      deliveryType: 'continuous',
      diagnosisNote: 'starting anyway',
    );

    expect(event.summaryLine, contains('PREBUFFER TIMEOUT'));
    expect(event.summaryLine, contains('starting anyway'));
  });

  test('prevents overlapping streaming diagnostics probes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(
      streamingDiagnosticsProbeBusyProvider.notifier,
    );
    final completer = Completer<void>();

    final first = notifier.runExclusive(() async {
      await completer.future;
      return 'done';
    });

    final second = notifier.runExclusive(() async => 'blocked');

    expect(container.read(streamingDiagnosticsProbeBusyProvider), isTrue);
    expect(second, completion(isNull));

    completer.complete();
    expect(await first, 'done');
    expect(container.read(streamingDiagnosticsProbeBusyProvider), isFalse);
  });
}
