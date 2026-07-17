import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface_state_layer.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

Material _surfaceMaterial(WidgetTester tester, Type type) {
  final finder = find.descendant(
    of: find.byType(type),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(finder);
}

void main() {
  test('maps each semantic surface level to its ColorScheme role', () {
    const colors = ColorScheme.dark(
      surface: Color(0xFF010101),
      surfaceContainerLow: Color(0xFF020202),
      surfaceContainer: Color(0xFF030303),
      surfaceContainerHigh: Color(0xFF040404),
      surfaceContainerHighest: Color(0xFF050505),
    );

    expect(AppSurfaceLevel.base.resolve(colors), colors.surface);
    expect(AppSurfaceLevel.low.resolve(colors), colors.surfaceContainerLow);
    expect(AppSurfaceLevel.standard.resolve(colors), colors.surfaceContainer);
    expect(AppSurfaceLevel.high.resolve(colors), colors.surfaceContainerHigh);
    expect(
      AppSurfaceLevel.highest.resolve(colors),
      colors.surfaceContainerHighest,
    );
  });

  test('uses the standard large shape unless a shape is supplied', () {
    final defaultShape = AppSurface.defaultShape(const AppShapes());
    expect(defaultShape, isA<RoundedRectangleBorder>());
    expect(
      (defaultShape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppShapes.standard.large),
    );
  });

  testWidgets('uses the supplied shape and level color', (tester) async {
    const customShape = StadiumBorder();
    await tester.pumpWidget(
      _host(
        const AppSurface(
          level: AppSurfaceLevel.high,
          shape: customShape,
          child: SizedBox(width: 20, height: 20),
        ),
      ),
    );

    final material = _surfaceMaterial(tester, AppSurface);
    expect(material.shape, customShape);
    expect(material.color, AppTheme.darkTheme.colorScheme.surfaceContainerHigh);
  });

  test('resolves distinct default, selected, and disabled state contracts', () {
    final colors = AppTheme.darkTheme.colorScheme;
    final status = AppTheme.darkTheme.extension<AppStatusColors>()!;

    final normal = AppSurfaceStateLayer.resolve(colors, status, {});
    final selected = AppSurfaceStateLayer.resolve(colors, status, {
      WidgetState.selected,
    });
    final disabled = AppSurfaceStateLayer.resolve(colors, status, {
      WidgetState.disabled,
      WidgetState.selected,
      WidgetState.hovered,
      WidgetState.pressed,
      WidgetState.focused,
    });

    expect(normal.surfaceColor, isNull);
    expect(normal.overlayColor.a, 0);
    expect(normal.contentOpacity, 1);
    expect(selected.surfaceColor, colors.primaryContainer);
    expect(selected.contentOpacity, 1);
    expect(disabled.surfaceColor, colors.surfaceContainerLow);
    expect(disabled.surfaceColor, isNot(selected.surfaceColor));
    expect(disabled.overlayColor, colors.onSurface.withValues(alpha: 0.12));
    expect(disabled.contentOpacity, 0.38);
    expect(disabled.hasFocusOutline, isFalse);
  });

  test('resolves semantic hover, pressed, and focus state layers', () {
    final colors = AppTheme.darkTheme.colorScheme;
    final status = AppTheme.darkTheme.extension<AppStatusColors>()!;

    final hover = AppSurfaceStateLayer.resolve(colors, status, {
      WidgetState.hovered,
    });
    final pressed = AppSurfaceStateLayer.resolve(colors, status, {
      WidgetState.pressed,
    });
    final focused = AppSurfaceStateLayer.resolve(colors, status, {
      WidgetState.focused,
    });

    expect(hover.overlayColor, colors.onSurface.withValues(alpha: 0.08));
    expect(pressed.overlayColor, colors.onSurface.withValues(alpha: 0.12));
    expect(focused.focusColor, status.focus);
    expect(focused.hasFocusOutline, isTrue);
    expect(AppSurfaceStateLayer.focusOutlineWidth, 2);
    expect(AppSurfaceStateLayer.focusOutlineGap, 2);
  });

  testWidgets('focus paints a spaced two-pixel status outline', (tester) async {
    await tester.pumpWidget(
      _host(
        const AppSurface(
          states: <WidgetState>{WidgetState.focused},
          child: SizedBox(width: 20, height: 20),
        ),
      ),
    );

    final decorations = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<ShapeDecoration>();
    final focusDecoration = decorations.singleWhere((decoration) {
      final shape = decoration.shape;
      return shape is OutlinedBorder &&
          shape.side.width == AppSurfaceStateLayer.focusOutlineWidth;
    });

    expect(
      (focusDecoration.shape as OutlinedBorder).side.color,
      AppTheme.darkTheme.extension<AppStatusColors>()!.focus,
    );

    final outline = tester.widget<Positioned>(
      find.byKey(const ValueKey<String>('app-surface-focus-outline')),
    );
    expect(
      outline.left,
      -(AppSurfaceStateLayer.focusOutlineWidth +
          AppSurfaceStateLayer.focusOutlineGap),
    );
    expect(outline.top, outline.left);
    expect(outline.right, outline.left);
    expect(outline.bottom, outline.left);
  });

  testWidgets('state foreground does not duplicate the material shape side', (
    tester,
  ) async {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: AppTheme.darkTheme.colorScheme.outline),
    );
    await tester.pumpWidget(
      _host(
        AppSurface(
          shape: shape,
          states: const <WidgetState>{WidgetState.hovered},
          child: const SizedBox(width: 20, height: 20),
        ),
      ),
    );

    expect(_surfaceMaterial(tester, AppSurface).shape, shape);
    final foregroundShape = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .single;
    expect((foregroundShape.shape as OutlinedBorder).side, BorderSide.none);
  });

  testWidgets('focus outline is layout-neutral for an unbounded card', (
    tester,
  ) async {
    const key = ValueKey<String>('unbounded-focus-surface');
    Widget surface(Set<WidgetState> states) => _host(
      AppSurface(
        key: key,
        states: states,
        child: const SizedBox(width: 96, height: 48),
      ),
    );

    await tester.pumpWidget(surface(const <WidgetState>{}));
    final unfocusedSize = tester.getSize(find.byKey(key));

    await tester.pumpWidget(surface(const <WidgetState>{WidgetState.focused}));
    final focusedSize = tester.getSize(find.byKey(key));

    expect(focusedSize, unfocusedSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus outline is layout-neutral inside tight bounds', (
    tester,
  ) async {
    const key = ValueKey<String>('tight-focus-surface');
    Widget surface(Set<WidgetState> states) => _host(
      Center(
        child: SizedBox(
          width: 56,
          height: 72,
          child: AppSurface(
            key: key,
            states: states,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await tester.pumpWidget(surface(const <WidgetState>{}));
    final unfocusedSize = tester.getSize(find.byKey(key));

    await tester.pumpWidget(surface(const <WidgetState>{WidgetState.focused}));
    final focusedSize = tester.getSize(find.byKey(key));

    expect(unfocusedSize, const Size(56, 72));
    expect(focusedSize, unfocusedSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled focus never paints an outline', (tester) async {
    await tester.pumpWidget(
      _host(
        const AppSurface(
          states: <WidgetState>{WidgetState.disabled, WidgetState.focused},
          child: SizedBox(width: 20, height: 20),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('app-surface-focus-outline')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected and disabled surfaces use their state colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: <Widget>[
            AppSurface(
              states: <WidgetState>{WidgetState.selected},
              child: SizedBox(width: 20, height: 20),
            ),
            AppSurface(
              states: <WidgetState>{WidgetState.disabled},
              child: SizedBox(width: 20, height: 20),
            ),
          ],
        ),
      ),
    );

    final materials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(AppSurface),
        matching: find.byType(Material),
      ),
    );
    expect(
      materials.first.color,
      AppTheme.darkTheme.colorScheme.primaryContainer,
    );
    expect(
      materials.last.color,
      AppTheme.darkTheme.colorScheme.surfaceContainerLow,
    );
    final opacities = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(AppSurface),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacities.first.opacity, 1);
    expect(opacities.last.opacity, 0.38);
  });

  testWidgets(
    'overlay is solid, elevated, and never installs a backdrop filter',
    (tester) async {
      await tester.pumpWidget(
        _host(const AppOverlaySurface(child: SizedBox(width: 20, height: 20))),
      );

      final material = _surfaceMaterial(tester, AppOverlaySurface);
      expect(
        material.color,
        AppTheme.darkTheme.colorScheme.surfaceContainerHighest,
      );
      expect(material.elevation, AppElevation.level3);
      expect(material.shape, isA<RoundedRectangleBorder>());
      expect(
        (material.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppShapes.standard.medium),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets('overlay preserves an explicit shape override', (tester) async {
    const shape = StadiumBorder();
    await tester.pumpWidget(
      _host(
        const AppOverlaySurface(
          shape: shape,
          child: SizedBox(width: 20, height: 20),
        ),
      ),
    );

    expect(_surfaceMaterial(tester, AppOverlaySurface).shape, shape);
  });
}
