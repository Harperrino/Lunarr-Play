import 'package:flutter/material.dart';

import '../theme/app_component_metrics.dart';
import 'app_surface_state_layer.dart';
import 'm3_slots.dart';

/// Semantic destinations for pane actions that appear in the Live chrome.
///
/// Keeping the destination data next to the control prevents categories and
/// the sender list from drifting apart in iconography, labels or semantics.
enum M3PaneTarget {
  categories(icon: Icons.layers_rounded, label: 'Kategorien'),
  channels(icon: Icons.format_list_bulleted_rounded, label: 'Senderliste');

  const M3PaneTarget({required this.icon, required this.label});

  final IconData icon;
  final String label;

  String actionLabel(bool expanded) =>
      expanded ? '$label einklappen' : '$label anzeigen';
}

/// Presentation-only control for opening and closing a pane.
///
/// It intentionally does not expose a selected-navigation state. The 48-dp
/// hit target and 40-dp visual stay stable while the reciprocal icon and
/// semantic label describe the current pane state.
class M3PaneToggleButton extends StatefulWidget {
  const M3PaneToggleButton({
    super.key,
    this.target,
    this.paneLabel,
    required this.expanded,
    required this.onPressed,
    this.focusNode,
    this.expandedTooltip,
    this.collapsedTooltip,
    this.showLabel,
    this.focusOutlineKey,
    this.focusOutlineStyle = AppFocusOutlineStyle.shape,
  }) : assert(target != null || paneLabel != null);

  /// Preferred for Live pane actions. The enum supplies the icon and German
  /// action vocabulary as one semantic contract.
  final M3PaneTarget? target;

  /// Legacy generic-pane label retained for the shell sidebar control.
  final String? paneLabel;
  final bool expanded;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final String? expandedTooltip;
  final String? collapsedTooltip;

  /// Target actions show their text by default; rails can opt into the icon
  /// variant while retaining the same target semantics.
  final bool? showLabel;
  final Key? focusOutlineKey;
  final AppFocusOutlineStyle focusOutlineStyle;

  @override
  State<M3PaneToggleButton> createState() => _M3PaneToggleButtonState();
}

class _M3PaneToggleButtonState extends State<M3PaneToggleButton> {
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

  String get _paneLabel => widget.target?.label ?? widget.paneLabel!;

  String get _actionLabel {
    final target = widget.target;
    if (target != null) return target.actionLabel(widget.expanded);
    final action = widget.expanded ? 'Collapse' : 'Expand';
    return widget.expanded
        ? (widget.expandedTooltip ?? '$action $_paneLabel')
        : (widget.collapsedTooltip ?? '$action $_paneLabel');
  }

  bool get _hasVisibleLabel =>
      widget.target != null && widget.showLabel != false;

  @override
  Widget build(BuildContext context) {
    if (widget.target != null && !_hasVisibleLabel) {
      return _buildCompactTargetAction(widget.target!);
    }

    if (widget.target != null) {
      return _buildLabeledTargetAction(context, widget.target!);
    }

    final colors = Theme.of(context).colorScheme;
    final actionLabel = widget.expanded ? 'Collapse' : 'Expand';
    final accessibleLabel = widget.expanded
        ? (widget.expandedTooltip ?? '$actionLabel ${widget.paneLabel}')
        : (widget.collapsedTooltip ?? '$actionLabel ${widget.paneLabel}');

    return M3ActionSlot(
      icon: widget.expanded
          ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded,
      glyphSize: AppComponentMetrics.slotGlyphSize,
      foregroundColor: colors.onSurfaceVariant,
      tooltip: accessibleLabel,
      semanticLabel: accessibleLabel,
      toggled: widget.expanded,
      selected: false,
      focusNode: _focusNode,
      focusOutlineKey: widget.focusOutlineKey,
      focusOutlineStyle: widget.focusOutlineStyle,
      onPressed: _handlePressed,
    );
  }

  Widget _buildCompactTargetAction(M3PaneTarget target) => M3ActionSlot(
    icon: null,
    tooltip: _actionLabel,
    semanticLabel: _actionLabel,
    toggled: widget.expanded,
    selected: false,
    focusNode: _focusNode,
    focusOutlineKey: widget.focusOutlineKey,
    focusOutlineStyle: widget.focusOutlineStyle,
    onPressed: _handlePressed,
    child: M3PaneTargetGlyph(
      targetIcon: target.icon,
      expanded: widget.expanded,
    ),
  );

  Widget _buildLabeledTargetAction(BuildContext context, M3PaneTarget target) {
    final colors = Theme.of(context).colorScheme;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    final states = <WidgetState>{
      if (_hovered) WidgetState.hovered,
      if (_focused) WidgetState.focused,
      if (_pressed) WidgetState.pressed,
    };
    final visual = AppSurfaceStateLayer(
      shape: shape,
      states: states,
      surfaceColor: Colors.transparent,
      defaultForegroundColor: colors.onSurfaceVariant,
      focusOutlineKey: widget.focusOutlineKey,
      focusOutlineStyle: widget.focusOutlineStyle,
      child: SizedBox(
        width: double.infinity,
        height: AppComponentMetrics.slotVisualSize,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              M3PaneTargetGlyph(
                targetIcon: target.icon,
                expanded: widget.expanded,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final action = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppComponentMetrics.slotHitTarget,
        minHeight: AppComponentMetrics.slotHitTarget,
        maxWidth: AppComponentMetrics.paneActionMaxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: _focusNode,
          canRequestFocus: true,
          onTap: _handlePressed,
          onFocusChange: _setFocused,
          onHover: _setHovered,
          onHighlightChanged: _setPressed,
          customBorder: shape,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Center(child: visual),
        ),
      ),
    );
    final semantics = Semantics(
      container: true,
      button: true,
      enabled: true,
      toggled: widget.expanded,
      label: _actionLabel,
      onTap: _handlePressed,
      child: action,
    );
    return Tooltip(message: _actionLabel, child: semantics);
  }

  void _setHovered(bool value) {
    if (_hovered != value && mounted) setState(() => _hovered = value);
  }

  void _setFocused(bool value) {
    if (_focused != value && mounted) setState(() => _focused = value);
  }

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }
}

/// Shared target-plus-chevron glyph for labeled and edge pane actions.
class M3PaneTargetGlyph extends StatelessWidget {
  const M3PaneTargetGlyph({
    super.key,
    required this.targetIcon,
    required this.expanded,
  });

  final IconData targetIcon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: AppComponentMetrics.slotVisualSize,
      height: AppComponentMetrics.slotVisualSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              targetIcon,
              size: AppComponentMetrics.slotGlyphSize,
              color: color,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              expanded
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
