import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Presentation-only tonal tap target with explicit hover, press and focus state.
class EpgInteractiveSurface extends StatefulWidget {
  const EpgInteractiveSurface({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.level = AppSurfaceLevel.low,
    this.padding,
    this.shape,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final AppSurfaceLevel level;
  final EdgeInsetsGeometry? padding;
  final OutlinedBorder? shape;

  @override
  State<EpgInteractiveSurface> createState() => _EpgInteractiveSurfaceState();
}

class _EpgInteractiveSurfaceState extends State<EpgInteractiveSurface> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  Set<WidgetState> get _states => <WidgetState>{
    if (_hovered) WidgetState.hovered,
    if (_focused) WidgetState.focused,
    if (_pressed) WidgetState.pressed,
  };

  void _setStateIfChanged(bool current, bool next, VoidCallback update) {
    if (current != next) setState(update);
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: widget.level,
      padding: widget.padding,
      shape: widget.shape,
      states: _states,
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        onTap: widget.onTap,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onHover: (value) =>
              _setStateIfChanged(_hovered, value, () => _hovered = value),
          onFocusChange: (value) =>
              _setStateIfChanged(_focused, value, () => _focused = value),
          onHighlightChanged: (value) =>
              _setStateIfChanged(_pressed, value, () => _pressed = value),
          child: widget.child,
        ),
      ),
    );
  }
}
