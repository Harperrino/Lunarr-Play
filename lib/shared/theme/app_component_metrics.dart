/// Shared geometry tokens for the Material 3 Expressive component family.
///
/// Keeping these values in one provider-free module prevents feature widgets
/// from inventing slightly different icon boxes and hit targets.
abstract final class AppComponentMetrics {
  static const double slotVisualSize = 40.0;
  static const double slotHitTarget = 48.0;
  static const double slotGlyphSize = 20.0;
  // Keeps named pane actions finite while leaving enough room for their
  // icon, direction chevron and label at the default text scale.
  static const double paneActionMaxWidth = 176.0;
  static const double tabIconSlotSize = 24.0;
  static const double outlineWidth = 1.0;
  static const double selectedOutlineWidth = 1.0;
}
