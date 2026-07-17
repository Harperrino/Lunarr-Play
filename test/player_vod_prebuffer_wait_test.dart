import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

void main() {
  test(
    'classifyVodPreBufferWait returns reached once target buffer is available',
    () {
      final now = DateTime(2026, 6, 14, 12);
      final deadline = now.add(const Duration(seconds: 30));

      expect(
        classifyVodPreBufferWait(
          buffered: const Duration(seconds: 12),
          targetSeconds: 10,
          now: now,
          deadline: deadline,
          isDisposed: false,
          isCurrentSession: true,
        ),
        VodPreBufferWaitStatus.reached,
      );
    },
  );

  test('classifyVodPreBufferWait cancels on stale session', () {
    final now = DateTime(2026, 6, 14, 12);
    final deadline = now.add(const Duration(seconds: 30));

    expect(
      classifyVodPreBufferWait(
        buffered: const Duration(seconds: 2),
        targetSeconds: 10,
        now: now,
        deadline: deadline,
        isDisposed: false,
        isCurrentSession: false,
      ),
      VodPreBufferWaitStatus.cancelled,
    );
  });

  test('classifyVodPreBufferWait cancels after dispose', () {
    final now = DateTime(2026, 6, 14, 12);
    final deadline = now.add(const Duration(seconds: 30));

    expect(
      classifyVodPreBufferWait(
        buffered: const Duration(seconds: 2),
        targetSeconds: 10,
        now: now,
        deadline: deadline,
        isDisposed: true,
        isCurrentSession: true,
      ),
      VodPreBufferWaitStatus.cancelled,
    );
  });

  test('classifyVodPreBufferWait times out after the deadline', () {
    final now = DateTime(2026, 6, 14, 12, 0, 31);
    final deadline = DateTime(2026, 6, 14, 12, 0, 30);

    expect(
      classifyVodPreBufferWait(
        buffered: const Duration(seconds: 2),
        targetSeconds: 10,
        now: now,
        deadline: deadline,
        isDisposed: false,
        isCurrentSession: true,
      ),
      VodPreBufferWaitStatus.timedOut,
    );
  });
}
