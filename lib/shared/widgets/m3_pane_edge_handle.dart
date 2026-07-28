import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

import '../theme/app_elevation.dart';
import '../theme/app_shapes.dart';
import 'app_surface_state_layer.dart';
import 'm3_pane_toggle_button.dart';

/// A quiet edge action for opening or closing a Live pane.
///
/// Its narrow carrier reads as part of the pane seam rather than a floating
/// toolbar button. The seam identifies the target; tooltip and semantics name
/// it explicitly, while the single chevron communicates only the movement.
class M3PaneEdgeHandle extends StatefulWidget {
  const M3PaneEdgeHandle({
    super.key,
    required this.target,
    required this.expanded,
    required this.onPressed,
    this.focusNode,
    this.focusOutlineKey,
    this.onHorizontalDragUpdate,
    this.onDragEnd,
    this.onDoubleTap,
    this.onResizeByKeyboard,
  });

  final M3PaneTarget target;
  final bool expanded;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final Key? focusOutlineKey;
  final ValueChanged<double>? onHorizontalDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDoubleTap;
  final ValueChanged<double>? onResizeByKeyboard;

  static const hitWidth = 48.0;
  static const hitHeight = 72.0;
  static const visualWidth = 28.0;
  static const visualHeight = 64.0;

  @override
  State<M3PaneEdgeHandle> createState() => _M3PaneEdgeHandleState();
}

/// Full-height resize seam for a pane.
///
/// This intentionally has no collapse action. The neighbouring
/// [M3PaneEdgeHandle] remains the small click/keyboard target, while this
/// opaque seam owns horizontal dragging and the double-click reset gesture.
class M3PaneResizeEdge extends StatefulWidget {
  const M3PaneResizeEdge({
    super.key,
    required this.onHorizontalDragUpdate,
    required this.onDragEnd,
    required this.onDoubleTap,
    this.onResizeByKeyboard,
  });

  static const hitWidth = 10.0;

  final ValueChanged<double> onHorizontalDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDoubleTap;
  final ValueChanged<double>? onResizeByKeyboard;

  @override
  State<M3PaneResizeEdge> createState() => _M3PaneResizeEdgeState();
}

class _M3PaneResizeEdgeState extends State<M3PaneResizeEdge> {
  bool _hovered = false;
  bool _focused = false;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final resize = widget.onResizeByKeyboard;
    if (resize == null) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      resize(-16);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      resize(16);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _hovered || _focused;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              widget.onHorizontalDragUpdate(details.delta.dx),
          onHorizontalDragEnd: (_) => widget.onDragEnd(),
          onDoubleTap: widget.onDoubleTap,
          child: Semantics(
            container: true,
            label: context.l10n.categoryPaneResizeLabel,
            hint: context.l10n.categoryPaneResizeHint,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: M3PaneResizeEdge.hitWidth,
              color: active
                  ? colors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

class _M3PaneEdgeHandleState extends State<M3PaneEdgeHandle> {
  FocusNode? _internalFocusNode;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _dragging = false;
  bool _doubleTapPending = false;
  Timer? _doubleTapTimer;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handlePressed() {
    widget.onPressed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final resize = widget.onResizeByKeyboard;
    if (resize != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        resize(-16);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        resize(16);
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _handlePressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (widget.onDoubleTap == null || _dragging) {
      _dragging = false;
      _doubleTapPending = false;
      _doubleTapTimer?.cancel();
      return;
    }

    if (_doubleTapPending) {
      _doubleTapPending = false;
      _doubleTapTimer?.cancel();
      widget.onDoubleTap!();
    } else {
      _doubleTapPending = true;
      _doubleTapTimer?.cancel();
      _doubleTapTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _doubleTapPending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final actionLabel = widget.target.localizedActionLabel(
      context,
      widget.expanded,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapes.full),
      side: BorderSide(color: colors.outlineVariant, width: 1),
    );
    final states = <WidgetState>{
      if (_hovered) WidgetState.hovered,
      if (_focused) WidgetState.focused,
      if (_pressed) WidgetState.pressed,
    };
    final visual = AppSurfaceStateLayer(
      shape: shape,
      states: states,
      surfaceColor: colors.surfaceContainerHighest,
      elevation: AppElevation.level1,
      defaultForegroundColor: colors.onSurfaceVariant,
      focusOutlineKey: widget.focusOutlineKey,
      focusOutlineStyle: AppFocusOutlineStyle.shape,
      child: SizedBox(
        width: M3PaneEdgeHandle.visualWidth,
        height: M3PaneEdgeHandle.visualHeight,
        child: ExcludeSemantics(
          child: Center(
            child: Icon(
              widget.expanded
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 24,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    final action = SizedBox(
      width: M3PaneEdgeHandle.hitWidth,
      height: M3PaneEdgeHandle.hitHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: true,
          onTap: _handlePressed,
          onFocusChange: (value) => setState(() => _focused = value),
          onHover: (value) => setState(() => _hovered = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          customBorder: shape,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Center(child: visual),
        ),
      ),
    );
    final gestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: widget.onHorizontalDragUpdate == null
          ? null
          : (details) {
              _dragging = true;
              widget.onHorizontalDragUpdate!(details.delta.dx);
            },
      onHorizontalDragEnd:
          widget.onHorizontalDragUpdate == null && widget.onDragEnd == null
          ? null
          : (_) {
              widget.onDragEnd?.call();
              _dragging = false;
            },
      child: action,
    );
    return Tooltip(
      message: actionLabel,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          onPointerDown: (_) {
            _dragging = false;
          },
          onPointerUp: _handlePointerUp,
          child: Semantics(
            container: true,
            button: true,
            enabled: true,
            toggled: widget.expanded,
            label: actionLabel,
            onTap: _handlePressed,
            child: gestures,
          ),
        ),
      ),
    );
  }
}
