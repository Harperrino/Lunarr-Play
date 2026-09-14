import 'dart:async';

import 'package:m3uxtream_player/core/logger/app_logger.dart';

/// Runs a UI-triggered asynchronous action without creating an unhandled
/// future. The action remains fire-and-forget for the caller, while failures
/// are routed through the central application logger.
void runDetached(Future<void> Function() action, {required String label}) {
  unawaited(
    Future<void>.sync(action).then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error('Detached action failed: $label', error, stackTrace);
      },
    ),
  );
}
