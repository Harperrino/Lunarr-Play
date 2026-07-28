import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';

var _appErrorHandlersInstalled = false;
AppErrorHandlersRestorer? _activeAppErrorHandlersRestorer;

/// Restores the previous global Flutter/platform error handlers.
class AppErrorHandlersRestorer {
  AppErrorHandlersRestorer._({
    required this.previousFlutterErrorHandler,
    required this.previousPlatformErrorHandler,
    required this.previousErrorWidgetBuilder,
  });

  final FlutterExceptionHandler? previousFlutterErrorHandler;
  final ErrorCallback? previousPlatformErrorHandler;
  final ErrorWidgetBuilder previousErrorWidgetBuilder;
  bool _restored = false;

  void restore() {
    if (_restored) return;
    _restored = true;

    FlutterError.onError = previousFlutterErrorHandler;
    PlatformDispatcher.instance.onError = previousPlatformErrorHandler;
    ErrorWidget.builder = previousErrorWidgetBuilder;

    if (identical(_activeAppErrorHandlersRestorer, this)) {
      _activeAppErrorHandlersRestorer = null;
      _appErrorHandlersInstalled = false;
    }
  }
}

/// Installs global Flutter/platform error handlers that mirror into AppLogger.
AppErrorHandlersRestorer installAppErrorHandlers() {
  if (_appErrorHandlersInstalled && _activeAppErrorHandlersRestorer != null) {
    return _activeAppErrorHandlersRestorer!;
  }

  final previousFlutterErrorHandler = FlutterError.onError;
  final previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
  final previousErrorWidgetBuilder = ErrorWidget.builder;
  final restorer = AppErrorHandlersRestorer._(
    previousFlutterErrorHandler: previousFlutterErrorHandler,
    previousPlatformErrorHandler: previousPlatformErrorHandler,
    previousErrorWidgetBuilder: previousErrorWidgetBuilder,
  );

  _activeAppErrorHandlersRestorer = restorer;
  _appErrorHandlersInstalled = true;

  FlutterError.onError = (details) {
    (previousFlutterErrorHandler ?? FlutterError.presentError)(details);

    final message = _formatFlutterErrorDetails(details);

    AppLogger.error(
      redactStreamText(message),
      redactStreamText(details.exceptionAsString()),
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(
      redactStreamText('Unhandled platform error: $error'),
      redactStreamText(error.toString()),
      stack,
    );
    return previousPlatformErrorHandler?.call(error, stack) ?? false;
  };

  ErrorWidget.builder = buildAppErrorFallback;

  return restorer;
}

/// A dependency-free fallback for a failed widget subtree.
///
/// The default debug [ErrorWidget] paints the complete available area red and
/// exposes an internal assertion. This replacement keeps the failure local and
/// readable while the full details continue to flow through [FlutterError].
Widget buildAppErrorFallback(FlutterErrorDetails details) {
  const background = Color(0xFF1B1B1F);
  const container = Color(0xFF2A292F);
  const accent = Color(0xFF9AD5AC);
  const foreground = Color(0xFFE6E1E5);
  const muted = Color(0xFFC9C5CA);

  return Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: background,
      child: Center(
        child: ConstrainedBox(
          key: const ValueKey('app-error-fallback'),
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: container,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 32, color: accent),
                  SizedBox(height: 16),
                  Text(
                    'This area could not be displayed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Details were written to Diagnostics / Logs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _formatFlutterErrorDetails(FlutterErrorDetails details) {
  final lines = <String>['FlutterError'];

  final library = details.library;
  if (library != null && library.isNotEmpty) {
    lines.add('library: $library');
  }

  final context = details.context?.toDescription();
  if (context != null && context.isNotEmpty) {
    lines.add('context: $context');
  }

  lines.add('exception: ${details.exceptionAsString()}');

  final collector = details.informationCollector;
  if (collector != null) {
    final infoLines = <String>[];
    try {
      for (final node in collector()) {
        final description = node.toDescription().trim();
        if (description.isEmpty) continue;
        infoLines.add(description);
        if (infoLines.length >= 6) break;
      }
    } catch (_) {
      // Keep error logging resilient even if an information collector fails.
    }

    if (infoLines.isNotEmpty) {
      lines.add('informationCollector:');
      lines.addAll(infoLines.map((line) => '  $line'));
    }
  }

  return lines.join('\n');
}
