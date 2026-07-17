import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
import 'package:m3uxtream_player/shared/theme/app_component_themes.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/app_spacing.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance >= secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance < secondLuminance
      ? firstLuminance
      : secondLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('defines all token extensions with canonical values', () {
    const status = AppStatusColors.dark;
    const spacing = AppSpacing.standard;
    const shapes = AppShapes.standard;
    const motion = AppMotion.standard;

    expect(status.live, const Color(0xFFFF667D));
    expect(status.onLive, const Color(0xFF41000D));
    expect(status.liveContainer, const Color(0xFF641526));
    expect(status.onLiveContainer, const Color(0xFFFFD9DE));
    expect(status.success, const Color(0xFF73DB91));
    expect(status.successContainer, const Color(0xFF0D4B28));
    expect(status.onSuccessContainer, const Color(0xFFA6F5B6));
    expect(status.warning, const Color(0xFFF2C66D));
    expect(status.warningContainer, const Color(0xFF503B00));
    expect(status.onWarningContainer, const Color(0xFFFFE39A));
    expect(status.info, const Color(0xFF82D0FF));
    expect(status.infoContainer, const Color(0xFF00364B));
    expect(status.onInfoContainer, const Color(0xFFC3E8FF));
    expect(status.focus, const Color(0xFFB6FFF0));

    expect(
      <double>[
        spacing.xs,
        spacing.sm,
        spacing.md,
        spacing.lg,
        spacing.xl,
        spacing.xxl,
        spacing.xxxl,
      ],
      <double>[4, 8, 12, 16, 24, 32, 40],
    );
    expect(
      <double>[
        spacing.compactContentGutter,
        spacing.mediumContentGutter,
        spacing.expandedContentGutter,
        spacing.wideContentGutter,
      ],
      <double>[12, 16, 24, 32],
    );
    expect(
      <double>[
        shapes.extraSmall,
        shapes.small,
        shapes.medium,
        shapes.large,
        shapes.extraLarge,
        shapes.full,
      ],
      <double>[4, 8, 12, 16, 24, 999],
    );
    expect(shapes.pill, BorderRadius.circular(999));
    expect(motion.state, const Duration(milliseconds: 120));
    expect(motion.content, const Duration(milliseconds: 180));
    expect(motion.rail, const Duration(milliseconds: 260));
    expect(motion.reduced, Duration.zero);
    expect(motion.standardCurve, Curves.easeOutCubic);
    expect(motion.emphasizedCurve, Curves.easeInOutCubic);
  });

  test('status colors support copyWith and lerp', () {
    final changed = AppStatusColors.dark.copyWith(live: Colors.white);
    expect(changed.live, Colors.white);
    expect(changed.success, AppStatusColors.dark.success);

    final midpoint = AppStatusColors.dark.lerp(changed, 0.5);
    expect(
      midpoint.live,
      Color.lerp(AppStatusColors.dark.live, Colors.white, 0.5),
    );
  });

  test('numeric and duration tokens support copyWith and lerp', () {
    final spacing = AppSpacing.standard.copyWith(xs: 12);
    expect(AppSpacing.standard.lerp(spacing, 0.5).xs, 8);

    final shapes = AppShapes.standard.copyWith(large: 24);
    expect(AppShapes.standard.lerp(shapes, 0.5).large, 20);

    final motion = AppMotion.standard.copyWith(
      state: const Duration(milliseconds: 240),
    );
    expect(
      AppMotion.standard.lerp(motion, 0.5).state,
      const Duration(milliseconds: 180),
    );
  });

  test('status text and focus roles meet contrast requirements', () {
    const status = AppStatusColors.dark;
    final textPairs = <(Color, Color)>[
      (status.onLive, status.live),
      (status.onLiveContainer, status.liveContainer),
      (status.onSuccessContainer, status.successContainer),
      (status.onWarningContainer, status.warningContainer),
      (status.onInfoContainer, status.infoContainer),
    ];
    for (final (foreground, background) in textPairs) {
      expect(
        _contrastRatio(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '$foreground on $background',
      );
    }

    for (final surface in <Color>[
      AppColorRoles.background,
      AppColorRoles.surface,
      AppColorRoles.surfaceContainer,
      AppColorRoles.surfaceContainerHighest,
    ]) {
      expect(
        _contrastRatio(status.focus, surface),
        greaterThanOrEqualTo(3),
        reason: 'focus on $surface',
      );
    }
  });

  test('component themes consume status focus and shape tokens', () {
    const colors = AppColorRoles.darkScheme;
    const status = AppStatusColors.dark;
    const shapes = AppShapes.standard;

    final input = AppComponentThemes.input(colors, status, shapes);
    final focusedBorder = input.focusedBorder! as OutlineInputBorder;
    final enabledBorder = input.enabledBorder! as OutlineInputBorder;
    expect(focusedBorder.borderSide, BorderSide(color: status.focus, width: 2));
    expect(focusedBorder.borderRadius, BorderRadius.circular(shapes.medium));
    expect(enabledBorder.borderRadius, BorderRadius.circular(shapes.medium));

    final tooltip = AppComponentThemes.tooltip(colors, shapes);
    final tooltipDecoration = tooltip.decoration! as BoxDecoration;
    expect(tooltipDecoration.borderRadius, BorderRadius.circular(shapes.small));

    final filledButton = AppComponentThemes.filledButton(status);
    expect(
      filledButton.side!.resolve(const <WidgetState>{WidgetState.focused}),
      BorderSide(color: status.focus, width: 2),
    );
    expect(filledButton.side!.resolve(const <WidgetState>{}), isNull);
  });
}
