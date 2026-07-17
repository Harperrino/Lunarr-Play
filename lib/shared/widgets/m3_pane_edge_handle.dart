import 'package:flutter/material.dart';

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
  });

  final M3PaneTarget target;
  final bool expanded;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final Key? focusOutlineKey;

  static const hitWidth = 48.0;
  static const hitHeight = 72.0;
  static const visualWidth = 28.0;
  static const visualHeight = 64.0;

  @override
  State<M3PaneEdgeHandle> createState() => _M3PaneEdgeHandleState();
}

class _M3PaneEdgeHandleState extends State<M3PaneEdgeHandle> {
  FocusNode? _internalFocusNode;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handlePressed() {
    widget.onPressed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final actionLabel = widget.target.actionLabel(widget.expanded);
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
          focusNode: _focusNode,
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
    return Tooltip(
      message: actionLabel,
      child: Semantics(
        container: true,
        button: true,
        enabled: true,
        toggled: widget.expanded,
        label: actionLabel,
        onTap: _handlePressed,
        child: action,
      ),
    );
  }
}
