import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'package:m3uxtream_player/core/constants/app_identity.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

const desktopWindowPlacementVersion = 1;
const desktopWindowPlacementFileName = 'desktop_window_placement.json';
const desktopWindowDefaultSize = Size(1440, 900);
const desktopWindowMinimumSize = Size(1080, 720);
const desktopWindowResizeDebounce = Duration(milliseconds: 400);

/// The only window state persisted by Lunarr.
///
/// Position, maximized state, minimized state and fullscreen state are
/// deliberately not part of this model. The next launch always starts as a
/// normal, centered window on the current primary display.
@immutable
class DesktopWindowPlacement {
  const DesktopWindowPlacement({required this.width, required this.height});

  final double width;
  final double height;

  Size get size => Size(width, height);

  Map<String, Object> toJson() => <String, Object>{
    'version': desktopWindowPlacementVersion,
    'width': width,
    'height': height,
  };

  static DesktopWindowPlacement? fromJson(Object? value) {
    if (value is! Map) return null;
    if (value['version'] != desktopWindowPlacementVersion) return null;

    final width = _finiteDouble(value['width']);
    final height = _finiteDouble(value['height']);
    if (width == null || height == null) return null;
    if (width < desktopWindowMinimumSize.width ||
        height < desktopWindowMinimumSize.height) {
      return null;
    }
    return DesktopWindowPlacement(width: width, height: height);
  }
}

double? _finiteDouble(Object? value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || !parsed.isFinite) return null;
  return parsed;
}

/// Small versioned runtime-file store for [DesktopWindowPlacement].
class DesktopWindowPlacementStore {
  // Keep the public `file:` injection point for deterministic tests and
  // platform-specific callers while storing it privately.
  DesktopWindowPlacementStore({File? file, this.supportDirectoryProvider})
    : _file = file; // ignore: prefer_initializing_formals

  final File? _file;
  final Future<Directory> Function()? supportDirectoryProvider;

  Future<File> get file async {
    final explicitFile = _file;
    if (explicitFile != null) return explicitFile;
    final directory =
        await (supportDirectoryProvider ?? getApplicationSupportDirectory)();
    return File(p.join(directory.path, desktopWindowPlacementFileName));
  }

  Future<Size?> load() async {
    try {
      final placementFile = await file;
      if (!await placementFile.exists()) return null;
      final decoded = jsonDecode(await placementFile.readAsString());
      return DesktopWindowPlacement.fromJson(decoded)?.size;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'DesktopWindowPlacement: Ignoring missing or corrupt placement file.',
      );
      AppLogger.debug('$error\n$stackTrace');
      return null;
    }
  }

  Future<void> save(Size size) async {
    final width = size.width;
    final height = size.height;
    if (!width.isFinite ||
        !height.isFinite ||
        width < desktopWindowMinimumSize.width ||
        height < desktopWindowMinimumSize.height) {
      return;
    }

    final placementFile = await file;
    await placementFile.parent.create(recursive: true);
    final temporaryFile = File('${placementFile.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode(DesktopWindowPlacement(width: width, height: height).toJson()),
      flush: true,
    );
    await temporaryFile.rename(placementFile.path);
  }
}

/// Pure sizing policy used by startup and its unit tests.
abstract final class DesktopWindowPlacementPolicy {
  static Size resolveSize({
    required Size? storedSize,
    required Size workAreaSize,
    Size fallbackSize = desktopWindowDefaultSize,
  }) {
    final candidate = _validCandidate(storedSize) ?? fallbackSize;
    final minimumWidth = math.min(
      desktopWindowMinimumSize.width,
      math.max(0.0, workAreaSize.width),
    );
    final minimumHeight = math.min(
      desktopWindowMinimumSize.height,
      math.max(0.0, workAreaSize.height),
    );
    final maxWidth = math.max(0.0, workAreaSize.width);
    final maxHeight = math.max(0.0, workAreaSize.height);

    return Size(
      math.min(maxWidth, math.max(minimumWidth, candidate.width)).toDouble(),
      math.min(maxHeight, math.max(minimumHeight, candidate.height)).toDouble(),
    );
  }

  static Offset centeredPosition({
    required Size windowSize,
    required Offset workAreaPosition,
    required Size workAreaSize,
  }) {
    return Offset(
      workAreaPosition.dx + (workAreaSize.width - windowSize.width) / 2,
      workAreaPosition.dy + (workAreaSize.height - windowSize.height) / 2,
    );
  }

  static Size? _validCandidate(Size? value) {
    if (value == null || !value.width.isFinite || !value.height.isFinite) {
      return null;
    }
    if (value.width < desktopWindowMinimumSize.width ||
        value.height < desktopWindowMinimumSize.height) {
      return null;
    }
    return value;
  }
}

/// Debounces normal-window resize events and flushes them before shutdown.
class DesktopWindowPlacementController {
  DesktopWindowPlacementController({
    DesktopWindowPlacementStore? store,
    Future<bool> Function()? isMaximized,
    Future<bool> Function()? isMinimized,
    Future<bool> Function()? isFullScreen,
    Future<Size> Function()? getSize,
  }) : _store = store ?? DesktopWindowPlacementStore(),
       _isMaximized = isMaximized ?? windowManager.isMaximized,
       _isMinimized = isMinimized ?? windowManager.isMinimized,
       _isFullScreen = isFullScreen ?? windowManager.isFullScreen,
       _getSize = getSize ?? windowManager.getSize;

  final DesktopWindowPlacementStore _store;
  final Future<bool> Function() _isMaximized;
  final Future<bool> Function() _isMinimized;
  final Future<bool> Function() _isFullScreen;
  final Future<Size> Function() _getSize;

  Timer? _persistTimer;
  Future<void>? _captureFuture;
  Size? _pendingSize;
  Future<void>? _flushFuture;
  bool _disposed = false;

  void onWindowResize({bool immersive = false}) {
    if (_disposed || immersive) return;
    final capture = _captureNormalSize();
    _captureFuture = capture;
    _persistTimer?.cancel();
    _persistTimer = Timer(desktopWindowResizeDebounce, () {
      unawaited(flush());
    });
  }

  Future<void> flush() {
    final existing = _flushFuture;
    if (existing != null) return existing;

    final future = _flushNow();
    _flushFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_flushFuture, future)) _flushFuture = null;
      }),
    );
    return future;
  }

  Future<void> _flushNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    final capture = _captureFuture;
    if (capture != null) await capture;
    await _captureNormalSize();

    final pending = _pendingSize;
    _pendingSize = null;
    if (pending == null) return;
    try {
      await _store.save(pending);
    } catch (error, stackTrace) {
      AppLogger.error(
        'DesktopWindowPlacement: Failed to persist window size.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _captureNormalSize() async {
    try {
      if (await _isMaximized() ||
          await _isMinimized() ||
          await _isFullScreen()) {
        return;
      }
      final size = await _getSize();
      if (!size.width.isFinite ||
          !size.height.isFinite ||
          size.width < desktopWindowMinimumSize.width ||
          size.height < desktopWindowMinimumSize.height) {
        return;
      }
      _pendingSize = size;
    } catch (error, stackTrace) {
      AppLogger.debug('DesktopWindowPlacement: Resize read skipped: $error');
      AppLogger.debug('$stackTrace');
    }
  }

  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    _persistTimer = null;
  }
}

Future<Size> resolveDesktopWindowSize({
  DesktopWindowPlacementStore? store,
  Future<Display> Function()? getPrimaryDisplay,
}) async {
  final placementStore = store ?? DesktopWindowPlacementStore();
  final storedSize = await placementStore.load();
  try {
    final display =
        await (getPrimaryDisplay ?? screenRetriever.getPrimaryDisplay)();
    final workAreaSize = display.visibleSize ?? display.size;
    if (workAreaSize.width > 0 && workAreaSize.height > 0) {
      return DesktopWindowPlacementPolicy.resolveSize(
        storedSize: storedSize,
        workAreaSize: workAreaSize,
      );
    }
  } catch (error, stackTrace) {
    AppLogger.warning(
      'DesktopWindowPlacement: Primary display lookup failed; using default size.',
    );
    AppLogger.debug('$error\n$stackTrace');
  }
  return DesktopWindowPlacementPolicy.resolveSize(
    storedSize: storedSize,
    workAreaSize: desktopWindowDefaultSize,
  );
}

WindowOptions desktopWindowOptionsFor(Size size) => WindowOptions(
  title: AppIdentity.displayName,
  size: size,
  minimumSize: desktopWindowMinimumSize,
  center: true,
  backgroundColor: const Color(0x00000000),
  titleBarStyle: TitleBarStyle.hidden,
  skipTaskbar: false,
);
