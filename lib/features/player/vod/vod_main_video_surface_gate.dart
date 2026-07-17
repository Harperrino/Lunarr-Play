import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True after [PlayerPanel] has mounted its main [Video] for the current VOD stream.
final vodMainVideoSurfaceReadyProvider = StateProvider<bool>((ref) => false);

typedef VodSurfaceClock = DateTime Function();
typedef VodSurfaceDelay = Future<void> Function(Duration duration);

Future<void> _defaultVodSurfaceDelay(Duration duration) {
  return Future<void>.delayed(duration);
}

/// Waits until the live-tab player surface is ready, with a bounded timeout.
Future<bool> waitForVodMainVideoSurface(
  bool Function() isReady, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 16),
  VodSurfaceClock now = DateTime.now,
  VodSurfaceDelay delay = _defaultVodSurfaceDelay,
}) async {
  final deadline = now().add(timeout);
  while (now().isBefore(deadline)) {
    if (isReady()) return true;
    await delay(pollInterval);
  }
  return isReady();
}

void resetVodMainVideoSurfaceReady(Ref ref) {
  ref.read(vodMainVideoSurfaceReadyProvider.notifier).state = false;
}
