import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:window_manager/window_manager.dart';

export 'package:m3uxtream_player/app/bootstrap/desktop_window_placement.dart';

import 'package:m3uxtream_player/app/bootstrap/desktop_window_placement.dart';

/// Desktop-only startup: single-instance guard and frameless window init.
Future<void> bootstrapDesktopWindow() async {
  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  if (!isDesktop) return;

  try {
    await windowManager.ensureInitialized();

    FlutterSingleInstance.onFocus = (_) async {
      try {
        await focusPrimaryDesktopWindow(
          isMinimized: windowManager.isMinimized,
          restore: windowManager.restore,
          show: windowManager.show,
          focus: windowManager.focus,
        );
      } catch (_) {
        AppLogger.warning(
          'App Startup: Failed restoring or focusing the primary window.',
        );
        rethrow;
      }
    };

    AppLogger.info('App Startup: Validating single application instance.');
    final singleInstance = FlutterSingleInstance();
    final shouldContinue = await ensurePrimaryDesktopInstance(
      isFirstInstance: singleInstance.isFirstInstance,
      focusPrimaryInstance: () => singleInstance.focus(),
    );
    if (!shouldContinue) {
      exit(0);
    }

    final initialSize = await resolveDesktopWindowSize();
    _desktopWindowOptions = desktopWindowOptionsFor(initialSize);
  } catch (e, stackTrace) {
    AppLogger.error(
      'App Startup FATAL: Failed desktop environment boot!',
      e,
      stackTrace,
    );
    rethrow;
  }
}

@visibleForTesting
Future<bool> ensurePrimaryDesktopInstance({
  required Future<bool> Function() isFirstInstance,
  required Future<String?> Function() focusPrimaryInstance,
}) async {
  if (await isFirstInstance()) {
    return true;
  }

  AppLogger.warning(
    'App Startup: Another instance is running. Focusing existing instance and terminating.',
  );

  try {
    final focusError = await focusPrimaryInstance();
    if (focusError != null) {
      AppLogger.warning(
        'App Startup: Primary instance focus request returned an error.',
      );
    }
  } catch (_) {
    AppLogger.warning('App Startup: Primary instance focus request failed.');
  }

  return false;
}

@visibleForTesting
Future<void> focusPrimaryDesktopWindow({
  required Future<bool> Function() isMinimized,
  required Future<void> Function() restore,
  required Future<void> Function() show,
  required Future<void> Function() focus,
}) async {
  if (await isMinimized()) {
    await restore();
  }
  await show();
  await focus();
}

WindowOptions _desktopWindowOptions = desktopWindowOptionsFor(
  desktopWindowDefaultSize,
);

WindowOptions get desktopWindowOptions => _desktopWindowOptions;
