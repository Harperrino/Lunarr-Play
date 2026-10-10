import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Keeps window_manager's state/events and repairs the Windows client bounds.
/// The native runner uses physical monitor coordinates, including the taskbar.
class DesktopFullscreen {
  static const _channel = MethodChannel('lunarr/fullscreen');
  static final _controller = DesktopFullscreenController(
    readEnabled: windowManager.isFullScreen,
    setEnabledOnWindow: windowManager.setFullScreen,
    prepare: (enabled) async {
      if (Platform.isWindows) {
        await _channel.invokeMethod<void>('prepare', enabled);
      }
    },
    finish: (enabled) async {
      if (!Platform.isWindows) return;
      if (enabled) {
        await _channel.invokeMethod<void>('fit');
      } else {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        await _channel.invokeMethod<void>('restore');
      }
    },
  );

  static Future<void> setEnabled(bool enabled) =>
      _controller.setEnabled(enabled);
}

/// One queue shared by the shell, Jellyfin, playback prep and shutdown.
class DesktopFullscreenController {
  DesktopFullscreenController({
    required this.readEnabled,
    required this.setEnabledOnWindow,
    required this.prepare,
    required this.finish,
  });

  final Future<bool> Function() readEnabled;
  final Future<void> Function(bool) setEnabledOnWindow;
  final Future<void> Function(bool) prepare;
  final Future<void> Function(bool) finish;
  Future<void> _pending = Future<void>.value();

  Future<void> setEnabled(bool enabled) {
    final operation = _pending.then((_) async {
      final previous = await readEnabled();
      if (previous == enabled) {
        if (enabled) await finish(true);
        return;
      }
      await prepare(enabled);
      try {
        await setEnabledOnWindow(enabled);
        await finish(enabled);
      } catch (_) {
        await prepare(previous);
        await setEnabledOnWindow(previous);
        await finish(previous);
        rethrow;
      }
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
