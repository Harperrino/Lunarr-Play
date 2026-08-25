import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

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

class RequestPlayerShortcutFocusIntent extends Intent {
  const RequestPlayerShortcutFocusIntent();
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
  PlayerShortcutManager({required super.shortcuts, this.shouldHandle});

  final bool Function()? shouldHandle;

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (isTextInputFocused() || shouldHandle?.call() == false) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }
}

/// Requests the surrounding player shortcut scope only when its video canvas
/// is clicked. Transport controls and all other interactive widgets keep focus.
class PlayerShortcutFocusRegion extends StatelessWidget {
  const PlayerShortcutFocusRegion({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        Actions.maybeInvoke(context, const RequestPlayerShortcutFocusIntent());
      },
      child: child,
    );
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

  /// Global playback actions are active only for Player A's visible tabs.
  final bool enabled;

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
    this.enabled = true,
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
  final FocusNode _shortcutFocusNode = FocusNode(
    debugLabel: 'GlobalShortcutsFocusTarget',
    skipTraversal: true,
  );
  late final PlayerShortcutManager _shortcutManager;

  @override
  void initState() {
    super.initState();
    _shortcutManager = PlayerShortcutManager(
      shortcuts: playerShortcutMap(
        channelNavigationEnabled: widget.channelNavigationEnabled,
      ),
      shouldHandle: () =>
          widget.enabled &&
          FocusManager.instance.primaryFocus == _shortcutFocusNode,
    );
    if (widget.enabled) {
      _requestShortcutsFocusAfterFrame();
    }
  }

  @override
  void didUpdateWidget(GlobalShortcutsWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channelNavigationEnabled != oldWidget.channelNavigationEnabled) {
      _shortcutManager.shortcuts = playerShortcutMap(
        channelNavigationEnabled: widget.channelNavigationEnabled,
      );
    }
    if (widget.enabled && !oldWidget.enabled) {
      _requestShortcutsFocusAfterFrame();
    }
    if (widget.requestFocusTrigger && !oldWidget.requestFocusTrigger) {
      _requestShortcutsFocusAfterFrame();
    }
  }

  void _requestShortcutsFocusAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Descendant autofocus registrations are applied in post-frame callbacks
      // too. The microtask lets those interactive controls win before the
      // otherwise empty player canvas claims keyboard shortcuts.
      Future<void>.microtask(_requestShortcutsFocus);
    });
  }

  void _requestShortcutsFocus() {
    if (!mounted || !widget.enabled || isTextInputFocused()) return;
    _shortcutFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _shortcutFocusNode.dispose();
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
              widget.onPlayPause?.call();
              return null;
            },
          ),
          ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
            onInvoke: (_) {
              widget.onToggleFullscreen?.call();
              return null;
            },
          ),
          ExitFullscreenIntent: CallbackAction<ExitFullscreenIntent>(
            onInvoke: (_) {
              widget.onExitFullscreen?.call();
              return null;
            },
          ),
          MuteIntent: CallbackAction<MuteIntent>(
            onInvoke: (_) {
              widget.onToggleMute?.call();
              return null;
            },
          ),
          VolumeUpIntent: CallbackAction<VolumeUpIntent>(
            onInvoke: (_) {
              widget.onVolumeAdjust?.call(0.05);
              return null;
            },
          ),
          VolumeDownIntent: CallbackAction<VolumeDownIntent>(
            onInvoke: (_) {
              widget.onVolumeAdjust?.call(-0.05);
              return null;
            },
          ),
          ChannelNextIntent: CallbackAction<ChannelNextIntent>(
            onInvoke: (_) {
              widget.onNextChannel?.call();
              return null;
            },
          ),
          ChannelPrevIntent: CallbackAction<ChannelPrevIntent>(
            onInvoke: (_) {
              widget.onPrevChannel?.call();
              return null;
            },
          ),
          RequestPlayerShortcutFocusIntent:
              CallbackAction<RequestPlayerShortcutFocusIntent>(
                onInvoke: (_) {
                  _requestShortcutsFocus();
                  return null;
                },
              ),
        },
        child: FocusScope(
          node: _focusScopeNode,
          debugLabel: 'GlobalShortcutsFocusScope',
          child: Focus(focusNode: _shortcutFocusNode, child: widget.child),
        ),
      ),
    );
  }
}
