import 'dart:math' as math;

/// Shared presentation metrics for the responsive Settings composition.
///
/// The navigation rail is intentionally treated as a complete layout unit:
/// its width, the gap to content and the minimum content width all have to
/// fit before the two-column layout is enabled.
class SettingsLayoutMetrics {
  SettingsLayoutMetrics._();

  // Keep the local navigation clearly larger than the former 184-dp rail,
  // without letting three destinations dominate a desktop Settings view.
  static const sectionNavigationWidth = 224.0;
  static const navigationContentGap = 16.0;
  static const minimumContentWidth = 640.0;
  static const contentMaxWidth = 760.0;
  static const compactWidth = 720.0;
  static const fullContentWidthTextScale = 1.5;
  static const desktopGroupMaxWidth =
      sectionNavigationWidth + navigationContentGap + contentMaxWidth;

  static double effectiveTextScale(double textScaleFactor) =>
      math.max(1.0, textScaleFactor);

  static double minimumContentWidthFor(double textScaleFactor) =>
      minimumContentWidth * effectiveTextScale(textScaleFactor);

  static bool usesFullContentWidth(double textScaleFactor) =>
      effectiveTextScale(textScaleFactor) >= fullContentWidthTextScale;

  static double navigationBreakpointFor(double textScaleFactor) =>
      sectionNavigationWidth +
      navigationContentGap +
      minimumContentWidthFor(textScaleFactor);

  static bool hasSectionNavigation({
    required double availableWidth,
    required double textScaleFactor,
  }) => availableWidth >= navigationBreakpointFor(textScaleFactor);
}
