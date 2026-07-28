import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

// ----------------------------------------------------
// GLOBAL HOTKEY INTENTS
// ----------------------------------------------------
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class ToggleFullscreenIntent extends Intent {
  const ToggleFullscreenIntent();
}

class ExitFullscreenIntent extends Intent {
  const ExitFullscreenIntent();
}

class MuteIntent extends Intent {
  const MuteIntent();
}

class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

class ChannelNextIntent extends Intent {
  const ChannelNextIntent();
}

class ChannelPrevIntent extends Intent {
  const ChannelPrevIntent();
}

/// True while the user is typing in a text field — player hotkeys must not fire.
@visibleForTesting
bool isTextInputFocused() {
  final focusNode = FocusManager.instance.primaryFocus;
  if (focusNode == null || !focusNode.hasFocus) return false;

  final focusContext = focusNode.context;
  if (focusContext == null) return false;

  if (focusContext.widget is EditableText) return true;

  // TextField focus sits on the inner Focus widget — not on the scope root.
  return focusContext.findAncestorWidgetOfExactType<TextField>() != null ||
      focusContext.findAncestorWidgetOfExactType<TextFormField>() != null;
}

@visibleForTesting
bool isPointerOnPrimaryTextInput(Offset globalPosition) {
  if (!isTextInputFocused()) return false;

  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;

  final renderObject = focusContext.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) return false;

  final local = renderObject.globalToLocal(globalPosition);
  return renderObject.size.contains(local);
}

/// Skips player shortcut matching while a text field has keyboard focus.
class PlayerShortcutManager extends ShortcutManager {
  PlayerShortcutManager({required super.shortcuts});

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (isTextInputFocused()) return KeyEventResult.ignored;
    return super.handleKeypress(context, event);
  }
}

Map<ShortcutActivator, Intent> playerShortcutMap({
  required bool channelNavigationEnabled,
}) {
  return <ShortcutActivator, Intent>{
    LogicalKeySet(LogicalKeyboardKey.space): const PlayPauseIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyF): const ToggleFullscreenIntent(),
    LogicalKeySet(LogicalKeyboardKey.escape): const ExitFullscreenIntent(),
    LogicalKeySet(LogicalKeyboardKey.keyM): const MuteIntent(),
    LogicalKeySet(LogicalKeyboardKey.equal): const VolumeUpIntent(),
    LogicalKeySet(LogicalKeyboardKey.numpadAdd): const VolumeUpIntent(),
    LogicalKeySet(LogicalKeyboardKey.minus): const VolumeDownIntent(),
    LogicalKeySet(LogicalKeyboardKey.numpadSubtract): const VolumeDownIntent(),
    if (channelNavigationEnabled) ...<ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.arrowDown): const ChannelNextIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowRight): const ChannelNextIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowUp): const ChannelPrevIntent(),
      LogicalKeySet(LogicalKeyboardKey.arrowLeft): const ChannelPrevIntent(),
    },
  };
}

// ----------------------------------------------------
// GLOBAL HOTKEY WIDGET WRAPPER
// ----------------------------------------------------
class GlobalShortcutsWrapper extends StatefulWidget {
  final Widget child;

  /// Whether arrow keys are reserved for Live channel navigation.
  ///
  /// Keep this disabled outside the Live tab so local focus and scrolling
  /// widgets can handle directional keys themselves.
  final bool channelNavigationEnabled;

  /// When this value changes to `true`, keyboard focus is re-requested (e.g. entering immersive mode).
  final bool requestFocusTrigger;

  final VoidCallback? onPlayPause;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onExitFullscreen;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeAdjust;
  final VoidCallback? onNextChannel;
  final VoidCallback? onPrevChannel;

  const GlobalShortcutsWrapper({
    super.key,
    required this.child,
    required this.channelNavigationEnabled,
    this.requestFocusTrigger = false,
    this.onPlayPause,
    this.onToggleFullscreen,
    this.onExitFullscreen,
    this.onToggleMute,
    this.onVolumeAdjust,
    this.onNextChannel,
    this.onPrevChannel,
  });

  @override
  State<GlobalShortcutsWrapper> createState() => _GlobalShortcutsWrapperState();
}

class _GlobalShortcutsWrapperState extends State<GlobalShortcutsWrapper> {
  final FocusScopeNode _focusScopeNode = FocusScopeNode(
    debugLabel: 'GlobalShortcutsFocusScope',
  );
  late final PlayerShortcutManager _shortcutManager;

  @override
  void initState() {
    super.initState();
    _shortcutManager = PlayerShortcutManager(
      shortcuts: playerShortcutMap(
        channelNavigationEnabled: widget.channelNavigationEnabled,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestShortcutsFocus(),
    );
  }

  @override
  void didUpdateWidget(GlobalShortcutsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channelNavigationEnabled != oldWidget.channelNavigationEnabled) {
      _shortcutManager.shortcuts = playerShortcutMap(
        channelNavigationEnabled: widget.channelNavigationEnabled,
      );
    }
    if (widget.requestFocusTrigger && !oldWidget.requestFocusTrigger) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _requestShortcutsFocus(),
      );
    }
  }

  void _requestShortcutsFocus() {
    if (!mounted || isTextInputFocused()) return;
    _focusScopeNode.requestFocus();
    AppLogger.info('GlobalShortcuts: Focus re-requested for hotkey scope.');
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (isPointerOnPrimaryTextInput(event.position)) return;

    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && isTextInputFocused()) {
      primary.unfocus();
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _requestShortcutsFocus(),
    );
  }

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts.manager(
      manager: _shortcutManager,
      child: Actions(
        actions: <Type, Action<Intent>>{
          PlayPauseIntent: CallbackAction<PlayPauseIntent>(
            onInvoke: (_) {
              AppLogger.info('Hotkey: SPACE (Play/Pause) triggered.');
              widget.onPlayPause?.call();
              return null;
            },
          ),
          ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
            onInvoke: (_) {
              AppLogger.info('Hotkey: F (Fullscreen Toggle) triggered.');
              widget.onToggleFullscreen?.call();
              return null;
            },
          ),
          ExitFullscreenIntent: CallbackAction<ExitFullscreenIntent>(
            onInvoke: (_) {
              AppLogger.info('Hotkey: ESC (Exit Fullscreen) triggered.');
              widget.onExitFullscreen?.call();
              return null;
            },
          ),
          MuteIntent: CallbackAction<MuteIntent>(
            onInvoke: (_) {
              AppLogger.info('Hotkey: M (Mute Toggle) triggered.');
              widget.onToggleMute?.call();
              return null;
            },
          ),
          VolumeUpIntent: CallbackAction<VolumeUpIntent>(
            onInvoke: (_) {
              AppLogger.info('Hotkey: + (Volume Up) triggered.');
              widget.onVolumeAdjust?.call(0.05);
              return null;
            },
          ),
          VolumeDownIntent: CallbackAction<VolumeDownIntent>(
            onInvoke: (_) {
              AppLogger.info('Hotkey: - (Volume Down) triggered.');
              widget.onVolumeAdjust?.call(-0.05);
              return null;
            },
          ),
          ChannelNextIntent: CallbackAction<ChannelNextIntent>(
            onInvoke: (_) {
              AppLogger.info(
                'Hotkey: ARROW DOWN/RIGHT (Next Channel) triggered.',
              );
              widget.onNextChannel?.call();
              return null;
            },
          ),
          ChannelPrevIntent: CallbackAction<ChannelPrevIntent>(
            onInvoke: (_) {
              AppLogger.info(
                'Hotkey: ARROW UP/LEFT (Previous Channel) triggered.',
              );
              widget.onPrevChannel?.call();
              return null;
            },
          ),
        },
        child: FocusScope(
          node: _focusScopeNode,
          autofocus: true,
          debugLabel: 'GlobalShortcutsFocusScope',
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
