import 'package:flutter/material.dart';

import 'app_status_colors.dart';

/// High-contrast dark roles used when the platform accessibility preference is enabled.
abstract final class HighContrastThemeRoles {
  static const colorScheme = ColorScheme.dark(
    primary: Color(0xFF9BF9EA),
    onPrimary: Color(0xFF00241F),
    primaryContainer: Color(0xFF1B695D),
    onPrimaryContainer: Color(0xFFD0FFF5),
    secondary: Color(0xFFB5EDFF),
    onSecondary: Color(0xFF002A35),
    secondaryContainer: Color(0xFF2E6977),
    onSecondaryContainer: Color(0xFFD5F5FF),
    tertiary: Color(0xFFFFE39A),
    onTertiary: Color(0xFF2D2300),
    tertiaryContainer: Color(0xFF725B00),
    onTertiaryContainer: Color(0xFFFFF0B8),
    error: Color(0xFFFFDAD6),
    onError: Color(0xFF410002),
    errorContainer: Color(0xFFB3261E),
    onErrorContainer: Color(0xFFFFEDEA),
    surface: Color(0xFF0B1417),
    surfaceDim: Color(0xFF071012),
    surfaceBright: Color(0xFF303A3D),
    surfaceContainerLowest: Color(0xFF081113),
    surfaceContainerLow: Color(0xFF0F191C),
    surfaceContainer: Color(0xFF152024),
    surfaceContainerHigh: Color(0xFF1B272B),
    surfaceContainerHighest: Color(0xFF223034),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFF1FFFC),
    outline: Color(0xFFD2E0DC),
    outlineVariant: Color(0xFF81908C),
    inverseSurface: Color(0xFFF0F7F5),
    onInverseSurface: Color(0xFF18201F),
    inversePrimary: Color(0xFF006B5E),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  static const statusColors = AppStatusColors(
    live: Color(0xFFFF9AAB),
    onLive: Color(0xFF370009),
    liveContainer: Color(0xFF8A1C35),
    onLiveContainer: Color(0xFFFFE9ED),
    success: Color(0xFF9DFFB0),
    successContainer: Color(0xFF126532),
    onSuccessContainer: Color(0xFFD5FFDC),
    warning: Color(0xFFFFE08A),
    warningContainer: Color(0xFF725600),
    onWarningContainer: Color(0xFFFFF1C2),
    info: Color(0xFFA5E4FF),
    infoContainer: Color(0xFF005A78),
    onInfoContainer: Color(0xFFE0F5FF),
    focus: Color(0xFFE8FFF9),
  );
}
