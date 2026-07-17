import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
    this.xxxl = 40,
    this.compactContentGutter = 12,
    this.mediumContentGutter = 16,
    this.expandedContentGutter = 24,
    this.wideContentGutter = 32,
  });

  static const standard = AppSpacing();

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double compactContentGutter;
  final double mediumContentGutter;
  final double expandedContentGutter;
  final double wideContentGutter;

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
    double? compactContentGutter,
    double? mediumContentGutter,
    double? expandedContentGutter,
    double? wideContentGutter,
  }) => AppSpacing(
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
    xxxl: xxxl ?? this.xxxl,
    compactContentGutter: compactContentGutter ?? this.compactContentGutter,
    mediumContentGutter: mediumContentGutter ?? this.mediumContentGutter,
    expandedContentGutter: expandedContentGutter ?? this.expandedContentGutter,
    wideContentGutter: wideContentGutter ?? this.wideContentGutter,
  );

  @override
  AppSpacing lerp(covariant AppSpacing? other, double t) {
    if (other == null) return this;
    double value(double a, double b) => lerpDouble(a, b, t)!;
    return AppSpacing(
      xs: value(xs, other.xs),
      sm: value(sm, other.sm),
      md: value(md, other.md),
      lg: value(lg, other.lg),
      xl: value(xl, other.xl),
      xxl: value(xxl, other.xxl),
      xxxl: value(xxxl, other.xxxl),
      compactContentGutter: value(
        compactContentGutter,
        other.compactContentGutter,
      ),
      mediumContentGutter: value(
        mediumContentGutter,
        other.mediumContentGutter,
      ),
      expandedContentGutter: value(
        expandedContentGutter,
        other.expandedContentGutter,
      ),
      wideContentGutter: value(wideContentGutter, other.wideContentGutter),
    );
  }
}
