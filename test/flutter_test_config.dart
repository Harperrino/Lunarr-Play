import 'dart:async';

import 'package:m3uxtream_player/core/logger/app_logger.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLogger.setConsoleOutputEnabledForTests(false);
  await testMain();
}
