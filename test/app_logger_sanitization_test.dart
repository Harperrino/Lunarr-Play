import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/providers/ui_logs_providers.dart';

void main() {
  setUp(() {
    AppLogger.clearHistory();
    AppLogger.setConsoleOutputEnabledForTests(false);
  });

  tearDown(() {
    AppLogger.setConsoleOutputEnabledForTests(true);
  });

  test(
    'sanitizes message, error, and stack before history and fan-out',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(uiLogsProvider);

      AppLogEntry? streamed;
      final subscription = AppLogger.events.listen((entry) => streamed = entry);
      addTearDown(subscription.cancel);

      AppLogger.error(
        'Open HTTPS://host.example/base/live/alice/sentinel-pass/42'
        '?API_KEY=sentinel-api',
        StateError(
          r'Failed at C:\Users\sentinel\Private Folder\config.json '
          'with token=sentinel-error',
        ),
        StackTrace.fromString(
          '#0 open '
          r'(C:\Users\sentinel\project\player.dart:10:2)'
          '\n#1 HTTPS://host.example/movie/alice/sentinel-pass/42'
          '?password=sentinel-stack',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final history = AppLogger.recentEvents.single;
      expect(identical(streamed, history), isTrue);
      final combined = [
        history.message,
        history.error,
        history.stackTrace,
        ...container.read(uiLogsProvider),
      ].join('\n');

      for (final sentinel in [
        'sentinel-pass',
        'sentinel-api',
        'sentinel-error',
        'sentinel-stack',
        r'C:\Users\sentinel',
      ]) {
        expect(combined, isNot(contains(sentinel)));
      }
      expect(history.message, contains('host.example'));
      expect(history.message, contains('42'));
      expect(history.error.toString(), contains('StateError'));
      expect(combined, contains('[LOCAL_PATH]'));
    },
  );

  test('preserves ordinary diagnostic text and error category', () {
    AppLogger.warning(
      'Playlist refresh failed after 120 ms.',
      StateError('Connection closed'),
    );

    final entry = AppLogger.recentEvents.single;
    expect(entry.message, 'Playlist refresh failed after 120 ms.');
    expect(entry.error.toString(), contains('StateError'));
    expect(entry.error.toString(), contains('Connection closed'));
  });

  test('release console policy keeps only warnings and errors', () {
    expect(
      AppLogger.consoleIncludesLevel(AppLogLevel.debug, debugBuild: false),
      isFalse,
    );
    expect(
      AppLogger.consoleIncludesLevel(AppLogLevel.info, debugBuild: false),
      isFalse,
    );
    expect(
      AppLogger.consoleIncludesLevel(AppLogLevel.warning, debugBuild: false),
      isTrue,
    );
    expect(
      AppLogger.consoleIncludesLevel(AppLogLevel.error, debugBuild: false),
      isTrue,
    );
  });
}
