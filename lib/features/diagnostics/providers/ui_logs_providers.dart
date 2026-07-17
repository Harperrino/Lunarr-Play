import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';

/// Diagnostic log lines shown in the real-time console panel.
const _kMaxUiLogEntries = 300;

class UiLogsNotifier extends StateNotifier<List<String>> {
  UiLogsNotifier() : super(_initialLogs);

  static const List<String> _initialLogs = [
    'System: UI engine initialized.',
    'System: Riverpod ProviderScope active.',
  ];

  StreamSubscription<AppLogEntry>? _appLogSubscription;
  DateTime _ignoreAppLogsBefore = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  void attachAppLogger(
    Stream<AppLogEntry> stream,
    Iterable<AppLogEntry> recentEvents,
  ) {
    for (final event in recentEvents) {
      _queueAppLog(event);
    }

    _appLogSubscription ??= stream.listen(_queueAppLog);
  }

  @override
  void dispose() {
    _disposed = true;
    _appLogSubscription?.cancel();
    super.dispose();
  }

  void _queueAppLog(AppLogEntry entry) {
    Future<void>.delayed(Duration.zero, () {
      if (_disposed) return;
      if (!entry.timestamp.isAfter(_ignoreAppLogsBefore)) return;
      _ingestAppLog(entry);
    });
  }

  void _appendLog(String log) {
    final next = [...state, log];
    state = next.length > _kMaxUiLogEntries
        ? next.sublist(next.length - _kMaxUiLogEntries)
        : next;
  }

  void _ingestAppLog(AppLogEntry entry) {
    if (entry.level == AppLogLevel.debug) return;

    final levelLabel = switch (entry.level) {
      AppLogLevel.debug => 'DEBUG',
      AppLogLevel.info => 'INFO',
      AppLogLevel.warning => 'WARN',
      AppLogLevel.error => 'ERROR',
    };

    final errorText = entry.error?.toString();
    final rendered = [
      'AppLogger[$levelLabel]',
      entry.message,
      if (errorText != null &&
          errorText.isNotEmpty &&
          errorText != entry.message)
        errorText,
    ].join(' | ');

    _appendLog(redactStreamText(rendered));
  }

  void addLog(String log) {
    final redacted = redactStreamText(log);
    _appendLog(redacted);
  }

  void clearLogs() {
    _ignoreAppLogsBefore = DateTime.now();
    AppLogger.clearHistory();
    state = [];
  }
}

final uiLogsProvider = StateNotifierProvider<UiLogsNotifier, List<String>>((
  ref,
) {
  final notifier = UiLogsNotifier();
  notifier.attachAppLogger(AppLogger.events, AppLogger.recentEvents);
  return notifier;
});
