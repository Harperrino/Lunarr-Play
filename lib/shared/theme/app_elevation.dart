import 'package:flutter/material.dart';

/// Describes whether a surface owns a fixed elevation or follows the
/// Material 3 Elevated Card state ladder.
enum AppElevationBehavior { staticSurface, elevatedCard }

/// Shared elevation ladder for Material 3 surfaces.
///
/// Tonal surface roles carry most of the hierarchy. Shadows are reserved for
/// the few surfaces that intentionally rise above their carrier.
abstract final class AppElevation {
  static const level0 = 0.0;
  static const level1 = 1.0;
  static const level2 = 3.0;
  static const level3 = 6.0;
  static const level4 = 8.0;

  /// Resolves a component's elevation without allowing local state ladders.
  ///
  /// Structural surfaces remain fixed by default. Only consumers that opt
  /// into [AppElevationBehavior.elevatedCard] receive the M3 card matrix:
  /// default/focus/pressed/disabled = 1 dp, hover = 3 dp and drag = 8 dp.
  static double resolveForStates(
    double base,
    Set<WidgetState> states, {
    AppElevationBehavior behavior = AppElevationBehavior.staticSurface,
  }) => switch (behavior) {
    AppElevationBehavior.staticSurface => base,
    AppElevationBehavior.elevatedCard => _resolveElevatedCard(base, states),
  };

  static double _resolveElevatedCard(double base, Set<WidgetState> states) {
    // A level-0 filled/outlined surface must never acquire a shadow merely
    // because a caller opted into the card resolver.
    if (base == level0) return level0;
    if (states.contains(WidgetState.disabled)) return level1;
    if (states.contains(WidgetState.dragged)) return level4;
    if (states.contains(WidgetState.hovered)) return level2;
    return level1;
  }

  /// Applies the shared shadow policy to a resolved elevation.
  ///
  /// The scheme's shadow role remains the sole color source. The centralized
  /// alpha calibration keeps level 1 quiet in dark themes while retaining a
  /// readable level-2 player separation.
  static Color shadowColorFor(ColorScheme colorScheme, double elevation) {
    final alpha = elevation <= level0
        ? 0.0
        : elevation <= level1
        ? 0.16
        : elevation <= level2
        ? 0.22
        : elevation <= level3
        ? 0.26
        : 0.30;
    return colorScheme.shadow.withValues(alpha: alpha);
  }
}
