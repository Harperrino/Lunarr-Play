import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

/// Deterministic accent colors for playlist category / genre labels.
abstract final class GroupAccent {
  static Color forGroup(String groupName) {
    if (groupName.isEmpty) return AppTheme.secondaryColor;

    const palette = <Color>[
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      AppTheme.accentColor,
      Color(0xFF7AE0A8), // Soft mint
      Color(0xFFF1B96E), // Gentle gold
      Color(0xFF71D7E8), // Light sea glass
    ];

    final index = groupName.hashCode.abs() % palette.length;
    return palette[index];
  }
}
