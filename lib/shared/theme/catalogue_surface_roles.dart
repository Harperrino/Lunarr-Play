import 'package:flutter/material.dart';

/// Shared Material roles for catalogue empty states and loading placeholders.
@immutable
class CatalogueSurfaceRoles {
  const CatalogueSurfaceRoles({
    required this.iconContainerStart,
    required this.iconContainerEnd,
    required this.iconContainerBorder,
    required this.onIconContainer,
    required this.subtitle,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.shimmerTile,
  });

  factory CatalogueSurfaceRoles.fromTheme(ThemeData theme) {
    final colors = theme.colorScheme;
    return CatalogueSurfaceRoles(
      iconContainerStart: colors.primaryContainer,
      iconContainerEnd: colors.secondaryContainer,
      iconContainerBorder: colors.outlineVariant,
      onIconContainer: colors.onPrimaryContainer,
      subtitle: colors.onSurfaceVariant,
      shimmerBase: colors.surfaceContainerLow,
      shimmerHighlight: colors.surfaceContainerHighest,
      shimmerTile: colors.surfaceContainer,
    );
  }

  static CatalogueSurfaceRoles of(BuildContext context) =>
      CatalogueSurfaceRoles.fromTheme(Theme.of(context));

  final Color iconContainerStart;
  final Color iconContainerEnd;
  final Color iconContainerBorder;
  final Color onIconContainer;
  final Color subtitle;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color shimmerTile;
}
