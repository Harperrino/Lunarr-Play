import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

/// Provider-free geometry and motion tokens shared by both playback engines.
@immutable
class PlayerChromeTokens extends ThemeExtension<PlayerChromeTokens> {
  const PlayerChromeTokens({
    this.compactBreakpoint = 620,
    this.wideBreakpoint = 680,
    this.surfaceRadius = 18,
    this.videoRadius = 18,
    this.panelRadius = 16,
    this.controlGap = 8,
    this.groupGap = 4,
    this.surfaceHorizontalPadding = 14,
    this.surfaceVerticalPadding = 12,
    this.compactSurfaceHorizontalPadding = 12,
    this.compactSurfaceVerticalPadding = 10,
    this.compactControlExtent = 36,
    this.controlExtent = 40,
    this.primaryCompactExtent = 48,
    this.primaryExtent = 56,
    this.compactIconExtent = 18,
    this.iconExtent = 20,
    this.primaryCompactIconExtent = 20,
    this.primaryIconExtent = 24,
    this.softScrimOpacity = 0.55,
    this.scrimOpacity = 0.78,
    this.strongScrimOpacity = 0.85,
  });

  static const standard = PlayerChromeTokens();

  final double compactBreakpoint;
  final double wideBreakpoint;
  final double surfaceRadius;
  final double videoRadius;
  final double panelRadius;
  final double controlGap;
  final double groupGap;
  final double surfaceHorizontalPadding;
  final double surfaceVerticalPadding;
  final double compactSurfaceHorizontalPadding;
  final double compactSurfaceVerticalPadding;
  final double compactControlExtent;
  final double controlExtent;
  final double primaryCompactExtent;
  final double primaryExtent;
  final double compactIconExtent;
  final double iconExtent;
  final double primaryCompactIconExtent;
  final double primaryIconExtent;
  final double softScrimOpacity;
  final double scrimOpacity;
  final double strongScrimOpacity;

  static PlayerChromeTokens of(BuildContext context) =>
      Theme.of(context).extension<PlayerChromeTokens>() ??
      PlayerChromeTokens.standard;

  @override
  PlayerChromeTokens copyWith({
    double? compactBreakpoint,
    double? wideBreakpoint,
    double? surfaceRadius,
    double? videoRadius,
    double? panelRadius,
    double? controlGap,
    double? groupGap,
    double? surfaceHorizontalPadding,
    double? surfaceVerticalPadding,
    double? compactSurfaceHorizontalPadding,
    double? compactSurfaceVerticalPadding,
    double? compactControlExtent,
    double? controlExtent,
    double? primaryCompactExtent,
    double? primaryExtent,
    double? compactIconExtent,
    double? iconExtent,
    double? primaryCompactIconExtent,
    double? primaryIconExtent,
    double? softScrimOpacity,
    double? scrimOpacity,
    double? strongScrimOpacity,
  }) => PlayerChromeTokens(
    compactBreakpoint: compactBreakpoint ?? this.compactBreakpoint,
    wideBreakpoint: wideBreakpoint ?? this.wideBreakpoint,
    surfaceRadius: surfaceRadius ?? this.surfaceRadius,
    videoRadius: videoRadius ?? this.videoRadius,
    panelRadius: panelRadius ?? this.panelRadius,
    controlGap: controlGap ?? this.controlGap,
    groupGap: groupGap ?? this.groupGap,
    surfaceHorizontalPadding:
        surfaceHorizontalPadding ?? this.surfaceHorizontalPadding,
    surfaceVerticalPadding:
        surfaceVerticalPadding ?? this.surfaceVerticalPadding,
    compactSurfaceHorizontalPadding:
        compactSurfaceHorizontalPadding ?? this.compactSurfaceHorizontalPadding,
    compactSurfaceVerticalPadding:
        compactSurfaceVerticalPadding ?? this.compactSurfaceVerticalPadding,
    compactControlExtent: compactControlExtent ?? this.compactControlExtent,
    controlExtent: controlExtent ?? this.controlExtent,
    primaryCompactExtent: primaryCompactExtent ?? this.primaryCompactExtent,
    primaryExtent: primaryExtent ?? this.primaryExtent,
    compactIconExtent: compactIconExtent ?? this.compactIconExtent,
    iconExtent: iconExtent ?? this.iconExtent,
    primaryCompactIconExtent:
        primaryCompactIconExtent ?? this.primaryCompactIconExtent,
    primaryIconExtent: primaryIconExtent ?? this.primaryIconExtent,
    softScrimOpacity: softScrimOpacity ?? this.softScrimOpacity,
    scrimOpacity: scrimOpacity ?? this.scrimOpacity,
    strongScrimOpacity: strongScrimOpacity ?? this.strongScrimOpacity,
  );

  @override
  PlayerChromeTokens lerp(covariant PlayerChromeTokens? other, double t) {
    if (other == null) return this;
    double l(double a, double b) => lerpDouble(a, b, t)!;
    return PlayerChromeTokens(
      compactBreakpoint: l(compactBreakpoint, other.compactBreakpoint),
      wideBreakpoint: l(wideBreakpoint, other.wideBreakpoint),
      surfaceRadius: l(surfaceRadius, other.surfaceRadius),
      videoRadius: l(videoRadius, other.videoRadius),
      panelRadius: l(panelRadius, other.panelRadius),
      controlGap: l(controlGap, other.controlGap),
      groupGap: l(groupGap, other.groupGap),
      surfaceHorizontalPadding: l(
        surfaceHorizontalPadding,
        other.surfaceHorizontalPadding,
      ),
      surfaceVerticalPadding: l(
        surfaceVerticalPadding,
        other.surfaceVerticalPadding,
      ),
      compactSurfaceHorizontalPadding: l(
        compactSurfaceHorizontalPadding,
        other.compactSurfaceHorizontalPadding,
      ),
      compactSurfaceVerticalPadding: l(
        compactSurfaceVerticalPadding,
        other.compactSurfaceVerticalPadding,
      ),
      compactControlExtent: l(compactControlExtent, other.compactControlExtent),
      controlExtent: l(controlExtent, other.controlExtent),
      primaryCompactExtent: l(primaryCompactExtent, other.primaryCompactExtent),
      primaryExtent: l(primaryExtent, other.primaryExtent),
      compactIconExtent: l(compactIconExtent, other.compactIconExtent),
      iconExtent: l(iconExtent, other.iconExtent),
      primaryCompactIconExtent: l(
        primaryCompactIconExtent,
        other.primaryCompactIconExtent,
      ),
      primaryIconExtent: l(primaryIconExtent, other.primaryIconExtent),
      softScrimOpacity: l(softScrimOpacity, other.softScrimOpacity),
      scrimOpacity: l(scrimOpacity, other.scrimOpacity),
      strongScrimOpacity: l(strongScrimOpacity, other.strongScrimOpacity),
    );
  }
}

enum PlayerChromeWidthClass { compact, regular, wide }

PlayerChromeWidthClass playerChromeWidthClassFor(
  double width,
  PlayerChromeTokens tokens,
) {
  if (width < tokens.compactBreakpoint) return PlayerChromeWidthClass.compact;
  if (width >= tokens.wideBreakpoint) return PlayerChromeWidthClass.wide;
  return PlayerChromeWidthClass.regular;
}
