import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_color_roles.dart';
import 'app_component_themes.dart';
import 'app_elevation.dart';
import 'app_motion.dart';
import 'app_shapes.dart';
import 'app_spacing.dart';
import 'app_status_colors.dart';
import 'high_contrast_theme_roles.dart';
import 'appearance_preferences.dart';

class AppTheme {
  @Deprecated('Use Theme.of(context).colorScheme.primary instead.')
  static const Color primaryColor = AppColorRoles.primary;
  @Deprecated('Use Theme.of(context).colorScheme.secondary instead.')
  static const Color secondaryColor = AppColorRoles.secondary;
  @Deprecated('Use Theme.of(context).colorScheme.tertiary instead.')
  static const Color accentColor = AppColorRoles.tertiary;
  @Deprecated('Use Theme.of(context).scaffoldBackgroundColor instead.')
  static const Color backgroundDb = AppColorRoles.background;

  static ThemeData get darkTheme => _buildDarkTheme(
    colors: AppColorRoles.darkScheme,
    status: AppStatusColors.dark,
  );

  static ThemeData darkThemeFor({
    double accentHue = AppearancePreferences.defaultAccentHue,
    double surfaceTone = AppearancePreferences.defaultSurfaceTone,
  }) {
    return _buildDarkTheme(
      colors: AppColorRoles.darkSchemeFor(
        accentHue: accentHue,
        surfaceTone: surfaceTone,
      ),
      status: AppStatusColors.dark,
    );
  }

  static ThemeData get highContrastDarkTheme => _buildDarkTheme(
    colors: HighContrastThemeRoles.colorScheme,
    status: HighContrastThemeRoles.statusColors,
  );

  static ThemeData _buildDarkTheme({
    required ColorScheme colors,
    required AppStatusColors status,
  }) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surfaceDim,
      canvasColor: colors.surface,
      dividerColor: colors.outlineVariant,
      focusColor: status.focus,
      highlightColor: colors.onSurface.withValues(alpha: 0.08),
      splashColor: colors.primary.withValues(alpha: 0.12),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppComponentThemes.filledButton(status),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppComponentThemes.outlinedButton(colors, status),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppComponentThemes.textButton(
          colors,
          status,
          AppShapes.standard,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppComponentThemes.elevatedButton(
          colors,
          status,
          AppShapes.standard,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: AppComponentThemes.iconButton(
          colors,
          status,
          AppShapes.standard,
        ),
      ),
      cardTheme: AppComponentThemes.card(colors, AppShapes.standard),
      dialogTheme: AppComponentThemes.dialog(colors, AppShapes.standard),
      bottomSheetTheme: AppComponentThemes.bottomSheet(
        colors,
        AppShapes.standard,
      ),
      popupMenuTheme: AppComponentThemes.popupMenu(colors, AppShapes.standard),
      listTileTheme: AppComponentThemes.listTile(colors, AppShapes.standard),
      navigationRailTheme: AppComponentThemes.navigationRail(
        colors,
        AppShapes.standard,
      ),
      navigationBarTheme: AppComponentThemes.navigationBar(colors),
      tabBarTheme: AppComponentThemes.tabBar(colors, AppShapes.standard),
      switchTheme: AppComponentThemes.switchControl(colors, status),
      checkboxTheme: AppComponentThemes.checkbox(
        colors,
        status,
        AppShapes.standard,
      ),
      radioTheme: AppComponentThemes.radio(colors, status),
      progressIndicatorTheme: AppComponentThemes.progress(colors),
      snackBarTheme: AppComponentThemes.snackBar(colors, AppShapes.standard),
      segmentedButtonTheme: AppComponentThemes.segmentedButton(
        colors,
        AppShapes.standard,
      ),
      inputDecorationTheme: AppComponentThemes.input(
        colors,
        status,
        AppShapes.standard,
      ),
      dropdownMenuTheme: AppComponentThemes.dropdownMenu(
        colors,
        status,
        AppShapes.standard,
      ),
      tooltipTheme: AppComponentThemes.tooltip(colors, AppShapes.standard),
      chipTheme: AppComponentThemes.chip(colors, status),
      extensions: <ThemeExtension<dynamic>>[
        status,
        AppSpacing.standard,
        AppShapes.standard,
        AppMotion.standard,
      ],
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: colors.onSurface,
          letterSpacing: -0.5,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: colors.onSurface),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: colors.onSurfaceVariant,
        ),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: colors.outline),
      ),
    );
  }
}
