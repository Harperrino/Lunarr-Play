import 'package:flutter/material.dart';

import '../theme/app_component_metrics.dart';
import '../theme/app_shapes.dart';
import 'app_surface_state_layer.dart';

/// A fixed visual column for leading icons and compact, non-interactive
/// trailing glyphs.
///
/// The child is intentionally centered inside a 40-dp box. Consumers may
/// provide a smaller custom visual, but the surrounding text axis stays
/// stable across lists, navigation and settings.
class M3LeadingSlot extends StatelessWidget {
  const M3LeadingSlot({
    super.key,
    this.icon,
    this.child,
    this.glyphSize = AppComponentMetrics.slotGlyphSize,
    this.foregroundColor,
    this.backgroundColor,
    this.shape,
    this.semanticLabel,
  }) : assert((icon == null) != (child == null));

  final IconData? icon;
  final Widget? child;
  final double glyphSize;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final OutlinedBorder? shape;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedShape =
        shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            (Theme.of(context).extension<AppShapes>() ?? AppShapes.standard)
                .medium,
          ),
        );
    final content =
        child ?? Icon(icon, size: glyphSize, color: foregroundColor);
    final slot = ConstrainedBox(
      constraints: const BoxConstraints.tightFor(
        width: AppComponentMetrics.slotVisualSize,
        height: AppComponentMetrics.slotVisualSize,
      ),
      child: Center(child: content),
    );
    final decorated = backgroundColor == null
        ? slot
        : Material(
            color: backgroundColor,
            shape: resolvedShape,
            clipBehavior: Clip.antiAlias,
            child: slot,
          );

    if (semanticLabel == null) return decorated;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: decorated),
    );
  }
}

/// A fixed-size expressive action with a 40-dp visual and 48-dp hit target.
///
/// The outer hit target owns pointer and keyboard interaction. The inner
/// state layer owns the bounded visual/focus treatment, so focus never
/// changes a row or card's layout geometry.
class M3ActionSlot extends StatefulWidget {
  const M3ActionSlot({
    super.key,
    this.icon,
    this.child,
    this.glyphSize = AppComponentMetrics.slotGlyphSize,
    this.foregroundColor,
    this.backgroundColor,
    this.shape,
    this.tooltip,
    this.semanticLabel,
    this.onPressed,
    this.enabled = true,
    this.selected = false,
    this.toggled,
    this.focusNode,
    this.focusOutlineKey,
    this.focusOutlineStyle = AppFocusOutlineStyle.shape,
  }) : assert((icon == null) != (child == null));

  final IconData? icon;
  final Widget? child;
  final double glyphSize;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final OutlinedBorder? shape;
  final String? tooltip;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool selected;
  final bool? toggled;
  final FocusNode? focusNode;
  final Key? focusOutlineKey;
  final AppFocusOutlineStyle focusOutlineStyle;

  @override
  State<M3ActionSlot> createState() => _M3ActionSlotState();
}

class _M3ActionSlotState extends State<M3ActionSlot> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onPressed != null;

  Set<WidgetState> get _states => <WidgetState>{
    if (widget.selected) WidgetState.selected,
    if (!_enabled) WidgetState.disabled,
    if (_hovered) WidgetState.hovered,
    if (_focused) WidgetState.focused,
    if (_pressed) WidgetState.pressed,
  };

  void _setStateValue(void Function() update) {
    if (mounted) setState(update);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final shape =
        widget.shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        );
    final content =
        widget.child ??
        Icon(
          widget.icon,
          size: widget.glyphSize,
          color: widget.foregroundColor ?? colors.onSurfaceVariant,
        );
    final visual = AppSurfaceStateLayer(
      shape: shape,
      states: _states,
      surfaceColor: widget.backgroundColor ?? colors.surfaceContainerHighest,
      focusOutlineKey: widget.focusOutlineKey,
      focusOutlineStyle: widget.focusOutlineStyle,
      child: SizedBox(
        width: AppComponentMetrics.slotVisualSize,
        height: AppComponentMetrics.slotVisualSize,
        child: Center(child: ExcludeSemantics(child: content)),
      ),
    );
    final action = SizedBox(
      width: AppComponentMetrics.slotHitTarget,
      height: AppComponentMetrics.slotHitTarget,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: widget.focusNode,
          canRequestFocus: _enabled,
          onTap: _enabled ? widget.onPressed : null,
          onFocusChange: (value) => _setStateValue(() => _focused = value),
          onHover: (value) =>
              _setStateValue(() => _hovered = _enabled && value),
          onHighlightChanged: (value) => _setStateValue(() => _pressed = value),
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
      enabled: _enabled,
      selected: widget.selected,
      toggled: widget.toggled,
      label: widget.semanticLabel ?? widget.tooltip,
      onTap: _enabled ? widget.onPressed : null,
      child: action,
    );
    final labelled = widget.tooltip == null
        ? semantics
        : Tooltip(message: widget.tooltip!, child: semantics);
    return labelled;
  }
}

/// Fixed icon geometry for tabs. The selected and unselected icon pair can
/// therefore swap glyphs without changing the tab's text axis.
class M3TabIconSlot extends StatelessWidget {
  const M3TabIconSlot({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppComponentMetrics.tabIconSlotSize,
      height: AppComponentMetrics.tabIconSlotSize,
      child: Center(child: Icon(icon, size: AppComponentMetrics.slotGlyphSize)),
    );
  }
}

/// A selected/unselected tab pair that keeps both glyphs in the same fixed
/// slot. Flutter's [Tab] does not expose a selectedIcon property, so the
/// controller is observed explicitly by the shared presentation primitive.
class M3TabIconPair extends StatelessWidget {
  const M3TabIconPair({
    super.key,
    required this.controller,
    required this.index,
    required this.icon,
    required this.selectedIcon,
  });

  final TabController controller;
  final int index;
  final IconData icon;
  final IconData selectedIcon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final selected = controller.animation?.value.round() == index;
        return M3TabIconSlot(icon: selected ? selectedIcon : icon);
      },
    );
  }
}
