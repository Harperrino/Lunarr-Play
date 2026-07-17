import 'package:flutter/material.dart';

abstract final class AppColorRoles {
  static const background = Color(0xFF071012);
  static const onBackground = Color(0xFFE2E9E7);
  static const surface = Color(0xFF0B1417);
  static const surfaceDim = Color(0xFF071012);
  static const surfaceBright = Color(0xFF303A3D);
  static const surfaceContainerLowest = Color(0xFF081113);
  static const surfaceContainerLow = Color(0xFF0F191C);
  static const surfaceContainer = Color(0xFF152024);
  static const surfaceContainerHigh = Color(0xFF1B272B);
  static const surfaceContainerHighest = Color(0xFF223034);
  static const onSurface = Color(0xFFE2E9E7);
  static const onSurfaceVariant = Color(0xFFBBC9C6);
  static const outline = Color(0xFF85938F);
  static const outlineVariant = Color(0xFF3E4B48);
  static const primary = Color(0xFF78D7C7);
  static const onPrimary = Color(0xFF003731);
  static const primaryContainer = Color(0xFF155047);
  static const onPrimaryContainer = Color(0xFFA5F2E3);
  static const secondary = Color(0xFF91CDE0);
  static const onSecondary = Color(0xFF003641);
  static const secondaryContainer = Color(0xFF234E5A);
  static const onSecondaryContainer = Color(0xFFBCEBFA);
  static const tertiary = Color(0xFFE7C36E);
  static const onTertiary = Color(0xFF3C2F00);
  static const tertiaryContainer = Color(0xFF574600);
  static const onTertiaryContainer = Color(0xFFFFE39A);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);
  static const inverseSurface = Color(0xFFDDE4E2);
  static const onInverseSurface = Color(0xFF2A3130);
  static const inversePrimary = Color(0xFF006B5E);
  static const scrim = Color(0xFF000000);
  static const shadow = Color(0xFF000000);

  static const darkScheme = ColorScheme.dark(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    shadow: shadow,
    scrim: scrim,
  );

  /// Builds the user-adjustable dark palette while keeping all semantic
  /// status roles outside the accent/surface controls.
  static ColorScheme darkSchemeFor({
    required double accentHue,
    required double surfaceTone,
  }) {
    final hue = accentHue % 360;
    final tone = surfaceTone.clamp(0, 1).toDouble();
    final surfaceBase = 0.038 + (tone * 0.05);

    Color neutral(double lightness) => HSLColor.fromAHSL(
      1,
      202,
      0.12,
      lightness.clamp(0, 1).toDouble(),
    ).toColor();

    // Use HSL only to create a stable input seed. The generated role tones
    // come from Flutter's Material 3 HCT tonal palette, so a hue sweep does
    // not make selected controls equally bright in every color family.
    final seedColor = HSLColor.fromAHSL(1, hue, 0.68, 0.52).toColor();
    final generated = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    return generated.copyWith(
      // Keep status roles independent from the user accent.
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      // Keep the app's neutral surface ladder independently tunable.
      surface: neutral(surfaceBase + 0.012),
      onSurface: neutral(0.92),
      surfaceDim: neutral(surfaceBase),
      surfaceBright: neutral(surfaceBase + 0.20),
      surfaceContainerLowest: neutral(surfaceBase - 0.012),
      surfaceContainerLow: neutral(surfaceBase + 0.024),
      surfaceContainer: neutral(surfaceBase + 0.045),
      surfaceContainerHigh: neutral(surfaceBase + 0.068),
      surfaceContainerHighest: neutral(surfaceBase + 0.092),
      onSurfaceVariant: neutral(0.76),
      outline: neutral(0.58),
      outlineVariant: neutral(0.31),
      inverseSurface: neutral(0.88),
      onInverseSurface: neutral(0.18),
      shadow: shadow,
      scrim: scrim,
      // Keep the inverse accent tied to the generated palette instead of
      // introducing a second hand-authored tone ladder.
      inversePrimary: generated.inversePrimary,
    );
  }
}
