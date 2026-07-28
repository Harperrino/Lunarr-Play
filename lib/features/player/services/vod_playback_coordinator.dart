import 'package:media_kit/media_kit.dart';

enum VodPreBufferWaitStatus { waiting, reached, cancelled, timedOut }

/// Behavior-neutral VOD preparation, forward-buffer, and resume mechanics.
final class VodPlaybackCoordinator {
  const VodPlaybackCoordinator();

  int nextForwardBufferMs({
    required int currentForwardBufferMs,
    required bool isBuffering,
    required Duration buffer,
    required int maximumBufferMs,
  }) {
    final cacheMs = buffer.inMilliseconds;
    if (cacheMs <= 0) return 0;
    if (!isBuffering) return currentForwardBufferMs;
    return cacheMs.clamp(0, maximumBufferMs);
  }

  VodPreBufferWaitStatus classifyPreBufferWait({
    required Duration buffered,
    required int targetSeconds,
    required DateTime now,
    required DateTime deadline,
    required bool isDisposed,
    required bool isCurrentSession,
  }) {
    if (isDisposed || !isCurrentSession) {
      return VodPreBufferWaitStatus.cancelled;
    }
    if (targetSeconds <= 0 || buffered.inSeconds >= targetSeconds) {
      return VodPreBufferWaitStatus.reached;
    }
    if (!now.isBefore(deadline)) {
      return VodPreBufferWaitStatus.timedOut;
    }
    return VodPreBufferWaitStatus.waiting;
  }

  Future<VodPreBufferWaitStatus> waitForPreBuffer({
    required Duration Function() currentBuffer,
    required int targetSeconds,
    required bool Function() isDisposed,
    required bool Function() isCurrentSession,
    Duration timeout = const Duration(seconds: 120),
    Duration pollInterval = const Duration(milliseconds: 200),
    DateTime Function()? now,
    Future<void> Function(Duration duration)? delay,
  }) async {
    final readNow = now ?? DateTime.now;
    final wait = delay ?? Future<void>.delayed;
    final deadline = readNow().add(timeout);

    while (true) {
      final status = classifyPreBufferWait(
        buffered: currentBuffer(),
        targetSeconds: targetSeconds,
        now: readNow(),
        deadline: deadline,
        isDisposed: isDisposed(),
        isCurrentSession: isCurrentSession(),
      );
      if (status != VodPreBufferWaitStatus.waiting) return status;
      await wait(pollInterval);
    }
  }

  Future<void> resumePrepared(Player player) => player.play();
}
