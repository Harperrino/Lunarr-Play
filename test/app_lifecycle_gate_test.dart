import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';

void main() {
  test(
    'runTracked returns the operation result and unregisters the job',
    () async {
      final gate = AppLifecycleGate();

      final result = await gate.runTracked(() async => 42);

      expect(result, 42);
      expect(gate.trackedJobCount, 0);
    },
  );

  test('runTracked registers the job while it is running', () async {
    final gate = AppLifecycleGate();
    final blocker = Completer<void>();

    final job = gate.runTracked(() => blocker.future.then((_) => 'done'));
    expect(gate.trackedJobCount, 1);

    blocker.complete();
    expect(await job, 'done');
    expect(gate.trackedJobCount, 0);
  });

  test('runTracked propagates errors and never blocks drain', () async {
    final gate = AppLifecycleGate();

    final failing = gate.runTracked<void>(() async => throw StateError('boom'));
    await expectLater(failing, throwsStateError);

    // The failed job must not escape as an unhandled future or block drain.
    await gate.drain();
    expect(gate.trackedJobCount, 0);
  });

  test('runTracked rejects new work after shutdown without starting it', () {
    final gate = AppLifecycleGate()..beginShutdown();
    var started = false;

    expect(
      () => gate.runTracked(() async {
        started = true;
      }),
      throwsStateError,
    );
    expect(started, isFalse);
    expect(gate.trackedJobCount, 0);
  });

  test('drain waits for every job registered before shutdown', () async {
    final gate = AppLifecycleGate();
    final first = Completer<void>();
    final second = Completer<void>();

    final firstJob = gate.runTracked(() => first.future);
    final secondJob = gate.runTracked(() => second.future);
    gate.beginShutdown();

    var drained = false;
    final drainFuture = gate.drain().then((_) => drained = true);
    await pumpEventQueue(times: 5);
    expect(drained, isFalse);

    first.complete();
    await firstJob;
    await pumpEventQueue(times: 5);
    expect(drained, isFalse);

    second.complete();
    await secondJob;
    await drainFuture;
    expect(drained, isTrue);
  });

  test('a job failing during drain lets the remaining jobs finish', () async {
    final gate = AppLifecycleGate();
    final slow = Completer<void>();

    final failing = gate.runTracked<void>(
      () async => throw StateError('failed job'),
    );
    final slowJob = gate.runTracked(() => slow.future);
    gate.beginShutdown();

    final drainFuture = gate.drain();
    await expectLater(failing, throwsStateError);
    slow.complete();
    await slowJob;
    await drainFuture;
    expect(gate.trackedJobCount, 0);
  });
}
