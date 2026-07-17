import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_shapes.dart';
import 'app_surface_state_layer.dart';

/// Solid elevated surface intended for temporary menus and overlays.
class AppOverlaySurface extends StatelessWidget {
  const AppOverlaySurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.shape,
    this.states = const <WidgetState>{},
    this.elevation = AppElevation.level3,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final OutlinedBorder? shape;
  final Set<WidgetState> states;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final resolvedShape =
        shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        );

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: AppSurfaceStateLayer(
        shape: resolvedShape,
        states: states,
        surfaceColor: colorScheme.surfaceContainerHighest,
        elevation: elevation,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
