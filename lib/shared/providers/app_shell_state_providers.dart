import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/services/fullscreen_toggle.dart';

/// Whether the app runs on a desktop platform (Windows, macOS, Linux).
final isDesktopPlatformProvider = Provider<bool>((ref) {
  return !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
});

/// Window-level fullscreen flag — synced with [windowManager] from main.dart.
final isFullscreenProvider = StateProvider<bool>((ref) => false);

/// Active sidebar tab index (0 = Live, 5 = Settings, 6 = Diagnostics when debug mode is enabled).
final activeSidebarIndexProvider = StateProvider<int>((ref) => 0);

/// Immersive live layout: desktop + window fullscreen + Live tab only.
final immersiveLayoutProvider = Provider<bool>((ref) {
  return resolveImmersiveLayout(
    isDesktop: ref.watch(isDesktopPlatformProvider),
    isWindowFullscreen: ref.watch(isFullscreenProvider),
    activeSidebarIndex: ref.watch(activeSidebarIndexProvider),
  );
});
