import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

void main() {
  test(
    'waitForLiveStartupBuffer returns reached when buffer already sufficient',
    () async {
      final result = await waitForLiveStartupBuffer(
        target: const Duration(seconds: 5),
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
        isSessionCurrent: () async => true,
        currentBuffer: () async => const Duration(seconds: 10),
      );

      expect(result, LiveStartupBufferWaitResult.reached);
    },
  );

  test(
    'waitForLiveStartupBuffer returns reached when buffer grows during wait',
    () async {
      final bufferValues = [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 5),
      ];
      var index = 0;

      final result = await waitForLiveStartupBuffer(
        target: const Duration(seconds: 5),
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
        isSessionCurrent: () async => true,
        currentBuffer: () async {
          final value = bufferValues[index];
          if (index < bufferValues.length - 1) index++;
          return value;
        },
      );

      expect(result, LiveStartupBufferWaitResult.reached);
    },
  );

  test(
    'waitForLiveStartupBuffer returns timedOut when target is not reached',
    () async {
      final result = await waitForLiveStartupBuffer(
        target: const Duration(seconds: 5),
        timeout: const Duration(milliseconds: 150),
        pollInterval: const Duration(milliseconds: 50),
        isSessionCurrent: () async => true,
        currentBuffer: () async => const Duration(seconds: 1),
      );

      expect(result, LiveStartupBufferWaitResult.timedOut);
    },
  );

  test(
    'waitForLiveStartupBuffer returns cancelled when session becomes stale',
    () async {
      var sessionCurrent = true;

      final future = waitForLiveStartupBuffer(
        target: const Duration(seconds: 5),
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
        isSessionCurrent: () async => sessionCurrent,
        currentBuffer: () async => const Duration(seconds: 1),
      );

      await Future<void>.delayed(const Duration(milliseconds: 60));
      sessionCurrent = false;

      final result = await future;
      expect(result, LiveStartupBufferWaitResult.cancelled);
    },
  );

  test(
    'waitForLiveStartupBuffer returns reached immediately when target is zero',
    () async {
      final result = await waitForLiveStartupBuffer(
        target: Duration.zero,
        timeout: const Duration(seconds: 10),
        pollInterval: const Duration(milliseconds: 50),
        isSessionCurrent: () async => true,
        currentBuffer: () async => Duration.zero,
      );

      expect(result, LiveStartupBufferWaitResult.reached);
    },
  );
}
