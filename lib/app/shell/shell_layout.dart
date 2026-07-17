import 'package:m3uxtream_player/shared/theme/app_spacing.dart';

/// Width classes for presentation-only shell layout decisions.
enum ShellWidthClass { compact, medium, expanded, wide }

/// Resolves the current layout class from the width actually available to it.
ShellWidthClass shellWidthClassFor(double width) {
  if (width < 720) return ShellWidthClass.compact;
  if (width < 1200) return ShellWidthClass.medium;
  if (width < 1600) return ShellWidthClass.expanded;
  return ShellWidthClass.wide;
}

/// Returns the adaptive shell gutter using theme spacing or stable defaults.
double shellContentGutterFor(double width, [AppSpacing? spacing]) {
  final tokens = spacing ?? AppSpacing.standard;
  return switch (shellWidthClassFor(width)) {
    ShellWidthClass.compact => tokens.compactContentGutter,
    ShellWidthClass.medium => tokens.mediumContentGutter,
    ShellWidthClass.expanded => tokens.expandedContentGutter,
    ShellWidthClass.wide => tokens.wideContentGutter,
  };
}
