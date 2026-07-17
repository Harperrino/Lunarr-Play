import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/live_startup_timing.dart';

void main() {
  setUp(AppLogger.clearRecentEventsForTests);

  test('measures phases cumulatively including exceptions', () async {
    var now = Duration.zero;
    final timing = LiveStartupTiming(elapsedNow: () => now)..start();

    await timing.measure(LiveStartupPhase.openAndSettle, () async {
      now += const Duration(milliseconds: 120);
    });
    await expectLater(
      timing.measure(LiveStartupPhase.openAndSettle, () async {
        now += const Duration(milliseconds: 80);
        throw StateError('failed');
      }),
      throwsStateError,
    );

    expect(
      timing.phaseDuration(LiveStartupPhase.openAndSettle),
      const Duration(milliseconds: 200),
    );
  });

  test('finish logs exactly once and freezes total', () {
    var now = const Duration(milliseconds: 40);
    final timing = LiveStartupTiming(elapsedNow: () => now)..start();

    expect(timing.finish(LiveStartupOutcome.success), isTrue);
    now = const Duration(seconds: 2);
    expect(timing.finish(LiveStartupOutcome.finalError), isFalse);

    final summaries = AppLogger.recentEvents
        .where((event) => event.message.startsWith('LiveStartupTiming:'))
        .toList();
    expect(summaries, hasLength(1));
    expect(summaries.single.message, contains('outcome=success'));
    expect(timing.total, const Duration(milliseconds: 40));
  });

  test('candidate phases and metadata accumulate independently', () async {
    var firstNow = Duration.zero;
    var secondNow = Duration.zero;
    final first = LiveStartupTiming(elapsedNow: () => firstNow)..start();
    final second = LiveStartupTiming(elapsedNow: () => secondNow)..start();

    first.recordCandidate(
      attemptLabel: 'URL1 (App/mpv)',
      headerProfile: 'App/mpv',
      delivery: 'continuous',
    );
    await first.measure(LiveStartupPhase.initialTracks, () async {
      firstNow += const Duration(milliseconds: 50);
    });
    second.recordCandidate(
      attemptLabel: 'URL2 (VLC)',
      headerProfile: 'VLC',
      delivery: 'hls',
    );
    secondNow += const Duration(milliseconds: 10);
    second.finish(LiveStartupOutcome.sessionAborted);

    expect(first.candidateCount, 1);
    expect(first.isFinished, isFalse);
    expect(
      first.phaseDuration(LiveStartupPhase.initialTracks),
      const Duration(milliseconds: 50),
    );
    expect(second.candidateCount, 1);
  });

  test('summary never exposes URLs, credentials, or control characters', () {
    final timing = LiveStartupTiming()..start();
    timing.recordCandidate(
      attemptLabel:
          'http://secret-user:secret-pass@example.invalid/live/secret-user/42?token=top-secret\nnext',
      headerProfile: 'App/mpv',
      delivery: 'continuous',
    );
    timing.finish(LiveStartupOutcome.finalError);

    final summary = AppLogger.recentEvents
        .singleWhere((event) => event.message.startsWith('LiveStartupTiming:'))
        .message;
    expect(summary, contains('attemptLabel=[redacted]'));
    expect(summary, isNot(contains('http://')));
    expect(summary, isNot(contains('secret-user')));
    expect(summary, isNot(contains('secret-pass')));
    expect(summary, isNot(contains('top-secret')));
    expect(summary, isNot(contains('\n')));
  });

  test(
    'play completion freezes success and play errors still propagate',
    () async {
      final success = LiveStartupTiming()..start();
      expect(
        await finishLiveStartupAfterPlay(
          timing: success,
          successOutcome: LiveStartupOutcome.success,
          isSessionCurrent: () => true,
          play: () async {},
        ),
        isTrue,
      );
      expect(success.isFinished, isTrue);

      final failure = LiveStartupTiming()..start();
      await expectLater(
        finishLiveStartupAfterPlay(
          timing: failure,
          successOutcome: LiveStartupOutcome.success,
          isSessionCurrent: () => true,
          play: () async => throw StateError('play failed'),
        ),
        throwsStateError,
      );
      expect(failure.isFinished, isFalse);
    },
  );

  test('stale session after play is logged as aborted, not success', () async {
    var current = true;
    final timing = LiveStartupTiming()..start();

    final released = await finishLiveStartupAfterPlay(
      timing: timing,
      successOutcome: LiveStartupOutcome.bestEffortSuccess,
      isSessionCurrent: () => current,
      play: () async {
        current = false;
      },
    );

    expect(released, isFalse);
    final summary = AppLogger.recentEvents
        .singleWhere((event) => event.message.startsWith('LiveStartupTiming:'))
        .message;
    expect(summary, contains('outcome=session-aborted'));
    expect(summary, isNot(contains('best-effort-success')));
  });
}
