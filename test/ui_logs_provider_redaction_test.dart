import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';

void main() {
  setUp(() {
    AppLogger.clearHistory();
  });

  test('redacts sensitive stream URLs before storing ui logs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(uiLogsProvider.notifier)
        .addLog(
          'Failed to open http://user:pass@iptv.example.com/live/user/pass/123?token=abc',
        );

    final logs = container.read(uiLogsProvider);
    expect(logs.last, isNot(contains('user:pass')));
    expect(logs.last, isNot(contains('token=abc')));
    expect(logs.last, contains('iptv.example.com'));
  });

  test('keeps only the latest 300 ui logs and drops older entries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(uiLogsProvider.notifier).clearLogs();

    for (var i = 0; i <= 300; i++) {
      container.read(uiLogsProvider.notifier).addLog('Log $i');
    }

    final logs = container.read(uiLogsProvider);
    expect(logs, hasLength(300));
    expect(logs.first, 'Log 1');
    expect(logs.last, 'Log 300');
  });

  test('clearLogs removes all ui log entries', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(uiLogsProvider.notifier).addLog('One');
    container.read(uiLogsProvider.notifier).addLog('Two');
    expect(container.read(uiLogsProvider), isNotEmpty);

    container.read(uiLogsProvider.notifier).clearLogs();

    expect(container.read(uiLogsProvider), isEmpty);
  });

  test(
    'clearLogs also clears AppLogger history and prevents stale rehydration',
    () async {
      final container = ProviderContainer();

      container.read(uiLogsProvider);
      AppLogger.info(
        'Player connected to http://user:pass@iptv.example.com/live/user/pass/123?token=abc',
      );

      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(uiLogsProvider),
        anyElement(contains('Player connected')),
      );

      container.read(uiLogsProvider.notifier).clearLogs();

      expect(container.read(uiLogsProvider), isEmpty);
      expect(AppLogger.recentEvents, isEmpty);

      container.dispose();

      final recreatedContainer = ProviderContainer();
      addTearDown(recreatedContainer.dispose);

      final rehydratedLogs = recreatedContainer.read(uiLogsProvider);
      expect(rehydratedLogs, isNot(anyElement(contains('Player connected'))));

      AppLogger.info('Player connected again after clear');
      await Future<void>.delayed(Duration.zero);
      expect(
        recreatedContainer.read(uiLogsProvider),
        anyElement(contains('Player connected again after clear')),
      );
    },
  );
}
