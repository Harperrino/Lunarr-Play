import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

const _testMotion = AppMotion(
  state: Duration(milliseconds: 80),
  reduced: Duration.zero,
  standardCurve: Curves.linear,
);

ThemeData _theme() => ThemeData(
  useMaterial3: true,
  colorScheme: AppTheme.darkTheme.colorScheme,
  extensions: const <ThemeExtension<dynamic>>[_testMotion],
);

Widget _host({
  required Set<WidgetState> states,
  required bool disableAnimations,
  double elevation = AppElevation.level1,
  AppElevationBehavior behavior = AppElevationBehavior.elevatedCard,
}) {
  return MaterialApp(
    theme: _theme(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Center(
          child: AppSurface(
            elevation: elevation,
            elevationBehavior: behavior,
            states: states,
            child: const SizedBox(width: 120, height: 64),
          ),
        ),
      ),
    ),
  );
}

Material _surfaceMaterial(WidgetTester tester) => tester.widget<Material>(
  find.descendant(of: find.byType(AppSurface), matching: find.byType(Material)),
);

void main() {
  testWidgets('elevated card uses shared motion and dark shadow policy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(states: const <WidgetState>{}, disableAnimations: false),
    );
    await tester.pump();

    var material = _surfaceMaterial(tester);
    expect(material.elevation, AppElevation.level1);
    expect(material.animationDuration, _testMotion.state);
    expect(
      material.shadowColor,
      AppElevation.shadowColorFor(_theme().colorScheme, AppElevation.level1),
    );
    expect((material.shape! as OutlinedBorder).side, BorderSide.none);

    await tester.pumpWidget(
      _host(
        states: const <WidgetState>{WidgetState.hovered},
        disableAnimations: false,
      ),
    );
    material = _surfaceMaterial(tester);
    expect(material.elevation, AppElevation.level2);
    expect(material.animationDuration, _testMotion.state);

    await tester.pumpWidget(
      _host(
        states: const <WidgetState>{WidgetState.dragged},
        disableAnimations: true,
      ),
    );
    material = _surfaceMaterial(tester);
    expect(material.elevation, AppElevation.level4);
    expect(material.animationDuration, Duration.zero);
  });

  testWidgets('static structural surfaces ignore pointer-state elevation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        states: const <WidgetState>{WidgetState.hovered, WidgetState.dragged},
        disableAnimations: false,
        elevation: AppElevation.level2,
        behavior: AppElevationBehavior.staticSurface,
      ),
    );
    await tester.pump();

    expect(_surfaceMaterial(tester).elevation, AppElevation.level2);
  });
}
