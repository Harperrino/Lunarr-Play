import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/bootstrap/desktop_window_bootstrap.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

void main() {
  setUp(AppLogger.clearRecentEventsForTests);

  test('first desktop instance continues without a focus request', () async {
    var focusCalls = 0;

    final shouldContinue = await ensurePrimaryDesktopInstance(
      isFirstInstance: () async => true,
      focusPrimaryInstance: () async {
        focusCalls++;
        return null;
      },
    );

    expect(shouldContinue, isTrue);
    expect(focusCalls, 0);
  });

  test('second desktop instance focuses primary and then stops', () async {
    var focusCalls = 0;

    final shouldContinue = await ensurePrimaryDesktopInstance(
      isFirstInstance: () async => false,
      focusPrimaryInstance: () async {
        focusCalls++;
        return null;
      },
    );

    expect(shouldContinue, isFalse);
    expect(focusCalls, 1);
  });

  test('focus errors never allow a second app instance to continue', () async {
    const privateDetail = 'user:secret@example.invalid';

    final shouldContinue = await ensurePrimaryDesktopInstance(
      isFirstInstance: () async => false,
      focusPrimaryInstance: () async => privateDetail,
    );

    expect(shouldContinue, isFalse);
    expect(
      AppLogger.recentEvents.map((event) => event.message).join('\n'),
      isNot(contains(privateDetail)),
    );
  });

  test('hidden primary window is shown and focused', () async {
    final calls = <String>[];

    await focusPrimaryDesktopWindow(
      isMinimized: () async => false,
      restore: () async => calls.add('restore'),
      show: () async => calls.add('show'),
      focus: () async => calls.add('focus'),
    );

    expect(calls, ['show', 'focus']);
  });

  test('minimized primary window is restored before focus', () async {
    final calls = <String>[];

    await focusPrimaryDesktopWindow(
      isMinimized: () async => true,
      restore: () async => calls.add('restore'),
      show: () async => calls.add('show'),
      focus: () async => calls.add('focus'),
    );

    expect(calls, ['restore', 'show', 'focus']);
  });
}
