import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_component_themes.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';

void main() {
  final colors = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.dark,
  );
  final status = AppStatusColors.dark;

  test('component theme matrix exposes the shared M3 families', () {
    expect(AppComponentThemes.filledButton(status), isA<ButtonStyle>());
    expect(
      AppComponentThemes.outlinedButton(colors, status),
      isA<ButtonStyle>(),
    );
    expect(
      AppComponentThemes.textButton(colors, status, AppShapes.standard),
      isA<ButtonStyle>(),
    );
    expect(
      AppComponentThemes.iconButton(colors, status, AppShapes.standard),
      isA<ButtonStyle>(),
    );
    expect(
      AppComponentThemes.card(colors, AppShapes.standard),
      isA<CardThemeData>(),
    );
    expect(
      AppComponentThemes.dialog(colors, AppShapes.standard),
      isA<DialogThemeData>(),
    );
    expect(
      AppComponentThemes.navigationRail(colors, AppShapes.standard),
      isA<NavigationRailThemeData>(),
    );
    expect(
      AppComponentThemes.segmentedButton(colors, AppShapes.standard),
      isA<SegmentedButtonThemeData>(),
    );
  });

  test(
    'state overlays distinguish hover, focus and pressed without literals',
    () {
      final style = AppComponentThemes.textButton(
        colors,
        status,
        AppShapes.standard,
      );
      final overlay = style.overlayColor!;
      expect(
        overlay.resolve({WidgetState.hovered}),
        colors.primary.withValues(alpha: 0.08),
      );
      expect(
        overlay.resolve({WidgetState.pressed}),
        colors.primary.withValues(alpha: 0.12),
      );
      expect(overlay.resolve(<WidgetState>{}), isNull);
    },
  );

  test('global CardTheme stays as the outlined Level-0 contract', () {
    final card = AppComponentThemes.card(colors, AppShapes.standard);
    expect(card.elevation, AppElevation.level0);
    expect(card.shadowColor, Colors.transparent);
    expect(card.shape, isA<RoundedRectangleBorder>());
  });
}
