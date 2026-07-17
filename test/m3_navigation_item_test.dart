import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

Widget _navigationHarness({
  required VoidCallback onPressed,
  bool selected = false,
  bool expanded = true,
  bool enabled = true,
  M3NavigationItemVisualRole visualRole = M3NavigationItemVisualRole.list,
  ThemeData? theme,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.dark,
  );
  return MaterialApp(
    theme: theme ?? ThemeData(useMaterial3: true, colorScheme: scheme),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: expanded ? 240 : 64,
          child: M3NavigationItem(
            label: 'Live TV',
            icon: Icons.live_tv_rounded,
            selected: selected,
            enabled: enabled,
            expanded: expanded,
            visualRole: visualRole,
            onPressed: onPressed,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('navigation item exposes selection and activates by pointer', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      _navigationHarness(onPressed: () => activations++, selected: true),
    );

    expect(find.text('Live TV'), findsOneWidget);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Live TV'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    expect(semantics.flagsCollection.isButton, isTrue);

    await tester.tap(find.byIcon(Icons.live_tv_rounded));
    expect(activations, 1);
  });

  testWidgets('compact navigation item keeps label semantics and tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _navigationHarness(onPressed: () {}, expanded: false),
    );

    expect(find.text('Live TV'), findsNothing);
    expect(find.byTooltip('Live TV'), findsOneWidget);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Live TV'));
    expect(semantics.label, contains('Live TV'));
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('disabled navigation item does not activate', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: M3NavigationItem(
            label: 'Disabled',
            icon: Icons.block_rounded,
            enabled: false,
            onPressed: () => activations++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.block_rounded));
    expect(activations, 0);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Disabled'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('navigation rail role uses one themed indicator in both modes', (
    tester,
  ) async {
    final theme = AppTheme.darkThemeFor(accentHue: 60);
    final indicator = theme.navigationRailTheme.indicatorColor;

    Future<void> pumpRail({required bool selected, required bool expanded}) {
      return tester.pumpWidget(
        _navigationHarness(
          onPressed: () {},
          selected: selected,
          expanded: expanded,
          visualRole: M3NavigationItemVisualRole.navigationRail,
          theme: theme,
        ),
      );
    }

    Future<void> expectRailIndicator({required bool selected}) async {
      final materials = tester.widgetList<Material>(
        find.descendant(
          of: find.byType(M3NavigationItem),
          matching: find.byType(Material),
        ),
      );
      expect(
        materials.any((material) => material.color == indicator),
        selected,
      );
      final animated = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(M3NavigationItem),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(animated.decoration, isNull);
    }

    await pumpRail(selected: true, expanded: false);
    await expectRailIndicator(selected: true);
    await pumpRail(selected: true, expanded: true);
    await expectRailIndicator(selected: true);
    await pumpRail(selected: false, expanded: false);
    await expectRailIndicator(selected: false);
  });

  testWidgets('rail selection follows high-contrast theme and disabled state', (
    tester,
  ) async {
    final theme = AppTheme.highContrastDarkTheme;
    await tester.pumpWidget(
      _navigationHarness(
        onPressed: () {},
        selected: true,
        enabled: false,
        visualRole: M3NavigationItemVisualRole.navigationRail,
        theme: theme,
      ),
    );

    final materials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(M3NavigationItem),
        matching: find.byType(Material),
      ),
    );
    expect(
      materials.any(
        (material) =>
            material.color == theme.navigationRailTheme.indicatorColor,
      ),
      isFalse,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Live TV'))
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
  });
}
