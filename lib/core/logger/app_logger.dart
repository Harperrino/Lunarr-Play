import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:m3uxtream_player/core/diagnostics/diagnostic_sanitizer.dart';

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
      // Call-site discovery walks the stack synchronously. Structured events
      // already retain explicitly supplied stacks, so routine console output
      // stays compact and allocation-light.
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 120,
      colors: true,
      printEmojis: false,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static final StreamController<AppLogEntry> _eventController =
      StreamController<AppLogEntry>.broadcast(sync: true);
  static final ListQueue<AppLogEntry> _recentEntries = ListQueue<AppLogEntry>();

  static Stream<AppLogEntry> get events => _eventController.stream;

  static List<AppLogEntry> get recentEvents =>
      List<AppLogEntry>.unmodifiable(_recentEntries);

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

  @visibleForTesting
  static bool consoleIncludesLevel(
    AppLogLevel level, {
    bool debugBuild = kDebugMode,
  }) {
    return debugBuild ||
        level == AppLogLevel.warning ||
        level == AppLogLevel.error;
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
    final safeMessage = DiagnosticSanitizer.sanitizeText(message).value;
    final safeError = error == null
        ? null
        : DiagnosticSanitizer.sanitizeError(error);
    final safeStackTrace = stackTrace == null
        ? null
        : DiagnosticSanitizer.sanitizeStackTrace(stackTrace);
    final entry = AppLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: safeMessage,
      error: safeError,
      stackTrace: safeStackTrace,
    );

    _recentEntries.add(entry);
    if (_recentEntries.length > _maxRecentEntries) {
      _recentEntries.removeFirst();
    }

    if (!_eventController.isClosed) {
      _eventController.add(entry);
    }

    if (!_consoleOutputEnabled || !consoleIncludesLevel(level)) return;

    switch (level) {
      case AppLogLevel.debug:
        _logger.d(safeMessage, error: safeError, stackTrace: safeStackTrace);
        break;
      case AppLogLevel.info:
        _logger.i(safeMessage, error: safeError, stackTrace: safeStackTrace);
        break;
      case AppLogLevel.warning:
        _logger.w(safeMessage, error: safeError, stackTrace: safeStackTrace);
        break;
      case AppLogLevel.error:
        _logger.e(safeMessage, error: safeError, stackTrace: safeStackTrace);
        break;
    }
  }
}
