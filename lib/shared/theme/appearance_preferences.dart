import 'package:flutter/foundation.dart';

/// User-owned visual preferences. Status and accessibility roles are not
/// represented here and therefore cannot be overridden by the accent picker.
@immutable
class AppearancePreferences {
  const AppearancePreferences({
    required this.accentHue,
    required this.surfaceTone,
  });

  static const double defaultAccentHue = 170;
  static const double defaultSurfaceTone = 0.5;

  static const defaults = AppearancePreferences(
    accentHue: defaultAccentHue,
    surfaceTone: defaultSurfaceTone,
  );

  final double accentHue;
  final double surfaceTone;

  AppearancePreferences copyWith({double? accentHue, double? surfaceTone}) {
    return AppearancePreferences(
      accentHue: (accentHue ?? this.accentHue).clamp(0, 360).toDouble(),
      surfaceTone: (surfaceTone ?? this.surfaceTone).clamp(0, 1).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppearancePreferences &&
        other.accentHue == accentHue &&
        other.surfaceTone == surfaceTone;
  }

  @override
  int get hashCode => Object.hash(accentHue, surfaceTone);
}
