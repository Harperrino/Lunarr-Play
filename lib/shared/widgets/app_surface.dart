import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_shapes.dart';
import 'app_surface_state_layer.dart';

/// Semantic tonal elevations for solid Material surfaces.
enum AppSurfaceLevel {
  base,
  low,
  standard,
  high,
  highest;

  Color resolve(ColorScheme colorScheme) => switch (this) {
    AppSurfaceLevel.base => colorScheme.surface,
    AppSurfaceLevel.low => colorScheme.surfaceContainerLow,
    AppSurfaceLevel.standard => colorScheme.surfaceContainer,
    AppSurfaceLevel.high => colorScheme.surfaceContainerHigh,
    AppSurfaceLevel.highest => colorScheme.surfaceContainerHighest,
  };
}

/// A solid, tonal Material surface with no blur or backdrop dependency.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.level = AppSurfaceLevel.standard,
    this.surfaceColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.shape,
    this.states = const <WidgetState>{},
    this.elevation = AppElevation.level0,
    this.elevationBehavior = AppElevationBehavior.staticSurface,
  });

  final Widget child;
  final AppSurfaceLevel level;

  /// Optional color override for presentation overlays that need translucency.
  /// The default remains the semantic tonal color resolved from [level].
  final Color? surfaceColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final OutlinedBorder? shape;
  final Set<WidgetState> states;
  final double elevation;
  final AppElevationBehavior elevationBehavior;

  static OutlinedBorder defaultShape(AppShapes? shapes) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          (shapes ?? AppShapes.standard).large,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedShape =
        shape ?? defaultShape(Theme.of(context).extension<AppShapes>());

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: AppSurfaceStateLayer(
        shape: resolvedShape,
        states: states,
        surfaceColor: surfaceColor ?? level.resolve(colorScheme),
        elevation: elevation,
        elevationBehavior: elevationBehavior,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
