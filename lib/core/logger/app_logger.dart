import 'dart:async';

import 'package:logger/logger.dart';

/// Central logging class for the IP-TV Player.
/// Adheres to the 'Striktes Logging' architectural guideline to trace database,
/// API, network, and Isolate-level events.
enum AppLogLevel { debug, info, warning, error }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

class AppLogger {
  static const int _maxRecentEntries = 300;
  static bool _consoleOutputEnabled = true;

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static final StreamController<AppLogEntry> _eventController =
      StreamController<AppLogEntry>.broadcast(sync: true);
  static final List<AppLogEntry> _recentEntries = <AppLogEntry>[];

  static Stream<AppLogEntry> get events => _eventController.stream;

  static List<AppLogEntry> get recentEvents =>
      List.unmodifiable(_recentEntries);

  static void clearHistory() {
    _recentEntries.clear();
  }

  static void clearRecentEventsForTests() {
    clearHistory();
  }

  /// Keeps structured events available while silencing the pretty-printer in
  /// automated tests. Production bootstrap never changes this flag.
  static void setConsoleOutputEnabledForTests(bool enabled) {
    _consoleOutputEnabled = enabled;
  }

  /// Log debug messages (general development information)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _emit(AppLogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  /// Log informational messages (key lifecycles, configuration switches)
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _emit(AppLogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  /// Log warning messages (non-fatal exceptions, recovery actions)
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _emit(AppLogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  /// Log critical errors (crashes, unhandled database anomalies, fatal parsing issues)
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _emit(AppLogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void _emit(
    AppLogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _recentEntries.add(entry);
    if (_recentEntries.length > _maxRecentEntries) {
      _recentEntries.removeRange(0, _recentEntries.length - _maxRecentEntries);
    }

    if (!_eventController.isClosed) {
      _eventController.add(entry);
    }

    if (!_consoleOutputEnabled) return;

    switch (level) {
      case AppLogLevel.debug:
        _logger.d(message, error: error, stackTrace: stackTrace);
        break;
      case AppLogLevel.info:
        _logger.i(message, error: error, stackTrace: stackTrace);
        break;
      case AppLogLevel.warning:
        _logger.w(message, error: error, stackTrace: stackTrace);
        break;
      case AppLogLevel.error:
        _logger.e(message, error: error, stackTrace: stackTrace);
        break;
    }
  }
}
