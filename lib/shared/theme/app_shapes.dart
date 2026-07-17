import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppShapes extends ThemeExtension<AppShapes> {
  const AppShapes({
    this.extraSmall = 4,
    this.small = 8,
    this.medium = 12,
    this.large = 16,
    this.extraLarge = 24,
    this.full = 999,
  });

  static const standard = AppShapes();

  final double extraSmall;
  final double small;
  final double medium;
  final double large;
  final double extraLarge;
  final double full;

  BorderRadius get pill => BorderRadius.circular(full);

  @override
  AppShapes copyWith({
    double? extraSmall,
    double? small,
    double? medium,
    double? large,
    double? extraLarge,
    double? full,
  }) => AppShapes(
    extraSmall: extraSmall ?? this.extraSmall,
    small: small ?? this.small,
    medium: medium ?? this.medium,
    large: large ?? this.large,
    extraLarge: extraLarge ?? this.extraLarge,
    full: full ?? this.full,
  );

  @override
  AppShapes lerp(covariant AppShapes? other, double t) {
    if (other == null) return this;
    return AppShapes(
      extraSmall: lerpDouble(extraSmall, other.extraSmall, t)!,
      small: lerpDouble(small, other.small, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      large: lerpDouble(large, other.large, t)!,
      extraLarge: lerpDouble(extraLarge, other.extraLarge, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}
