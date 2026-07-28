import 'package:flutter_test/flutter_test.dart';

import 'package:m3uxtream_player/features/player/services/vod_playback_coordinator.dart';

void main() {
  const coordinator = VodPlaybackCoordinator();

  test('forward buffer resets, advances only while buffering, and clamps', () {
    expect(
      coordinator.nextForwardBufferMs(
        currentForwardBufferMs: 9000,
        isBuffering: false,
        buffer: Duration.zero,
        maximumBufferMs: 120000,
      ),
      0,
    );
    expect(
      coordinator.nextForwardBufferMs(
        currentForwardBufferMs: 9000,
        isBuffering: false,
        buffer: const Duration(seconds: 20),
        maximumBufferMs: 120000,
      ),
      9000,
    );
    expect(
      coordinator.nextForwardBufferMs(
        currentForwardBufferMs: 9000,
        isBuffering: true,
        buffer: const Duration(seconds: 200),
        maximumBufferMs: 120000,
      ),
      120000,
    );
  });

  test('pre-buffer wait reaches target after polling', () async {
    var buffered = Duration.zero;

    final result = await coordinator.waitForPreBuffer(
      currentBuffer: () => buffered,
      targetSeconds: 10,
      isDisposed: () => false,
      isCurrentSession: () => true,
      delay: (_) async {
        buffered = const Duration(seconds: 10);
      },
    );

    expect(result, VodPreBufferWaitStatus.reached);
  });

  test('pre-buffer wait cancels when the session becomes stale', () async {
    var current = true;

    final result = await coordinator.waitForPreBuffer(
      currentBuffer: () => Duration.zero,
      targetSeconds: 10,
      isDisposed: () => false,
      isCurrentSession: () => current,
      delay: (_) async {
        current = false;
      },
    );

    expect(result, VodPreBufferWaitStatus.cancelled);
  });

  test('pre-buffer timeout remains a non-exception result', () async {
    final started = DateTime(2026);
    var now = started;

    final result = await coordinator.waitForPreBuffer(
      currentBuffer: () => Duration.zero,
      targetSeconds: 10,
      isDisposed: () => false,
      isCurrentSession: () => true,
      timeout: const Duration(seconds: 1),
      now: () => now,
      delay: (_) async {
        now = started.add(const Duration(seconds: 1));
      },
    );

    expect(result, VodPreBufferWaitStatus.timedOut);
  });
}
