import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/category_sidebar.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 260, height: 420, child: child)),
  );
}

Widget _wrapDirectional(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(navigationMode: NavigationMode.directional),
        child: SizedBox(width: 260, height: 420, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('category surfaces follow normal and high-contrast roles', (
    tester,
  ) async {
    Future<void> pumpSidebar(bool highContrast) async {
      final theme = highContrast
          ? AppTheme.highContrastDarkTheme
          : AppTheme.darkTheme;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<bool>(highContrast),
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 260,
              height: 420,
              child: CategorySidebar(
                groups: const ['Alpha', 'Beta'],
                selectedGroup: 'Alpha',
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpSidebar(false);
    final normalColors = AppTheme.darkTheme.colorScheme;
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).level,
      AppSurfaceLevel.low,
    );
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).elevation,
      AppElevation.level1,
    );
    expect(
      tester.widget<Text>(find.text('CATEGORIES')).style?.color,
      normalColors.onSurfaceVariant,
    );
    expect(
      tester.widget<Text>(find.text('Alpha')).style?.color,
      normalColors.onSecondaryContainer,
    );
    expect(
      tester.widget<Text>(find.text('Beta')).style?.color,
      normalColors.onSurfaceVariant,
    );
    final normalSelectedItem = find.ancestor(
      of: find.text('Alpha'),
      matching: find.byType(M3NavigationItem),
    );
    expect(
      tester
          .widgetList<Material>(
            find.descendant(
              of: normalSelectedItem,
              matching: find.byType(Material),
            ),
          )
          .any((material) => material.color == normalColors.secondaryContainer),
      isTrue,
    );
    expect(
      tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .every((tile) => tile.decoration == null),
      isTrue,
    );

    await pumpSidebar(true);
    final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(
      tester.widget<Text>(find.text('CATEGORIES')).style?.color,
      highContrastColors.onSurfaceVariant,
    );
    expect(
      tester.widget<Text>(find.text('Beta')).style?.color,
      highContrastColors.onSurfaceVariant,
    );
    expect(
      tester
          .widgetList<Material>(
            find.descendant(
              of: find.ancestor(
                of: find.text('Alpha'),
                matching: find.byType(M3NavigationItem),
              ),
              matching: find.byType(Material),
            ),
          )
          .any(
            (material) =>
                material.color == highContrastColors.secondaryContainer,
          ),
      isTrue,
    );
    expect(
      normalColors.outlineVariant,
      isNot(highContrastColors.outlineVariant),
    );
  });

  testWidgets('shows a subtle pin indicator for pinned groups but not All', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CategorySidebar(
          groups: const ['Alpha', 'Beta'],
          selectedGroup: 'Alpha',
          pinnedGroups: const ['Beta'],
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
  });

  testWidgets('category list owns one scrollbar on desktop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme.copyWith(platform: TargetPlatform.windows),
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 240,
            child: CategorySidebar(
              groups: List<String>.generate(40, (index) => 'Group $index'),
              selectedGroup: 'Group 0',
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('category rows expose selected button semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        CategorySidebar(
          groups: const ['Alpha', 'Beta'],
          selectedGroup: 'Alpha',
          onSelected: (_) {},
        ),
      ),
    );

    final alpha = find.bySemanticsLabel('Alpha');
    expect(alpha, findsOneWidget);
    expect(
      tester.getSemantics(alpha),
      matchesSemantics(
        label: 'Alpha',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    semantics.dispose();
  });

  testWidgets('category rows are keyboard focusable and activate on Enter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final selectedGroups = <String>[];

    await tester.pumpWidget(
      _wrap(
        CategorySidebar(
          groups: const ['Alpha', 'Beta'],
          selectedGroup: 'Alpha',
          onSelected: selectedGroups.add,
        ),
      ),
    );

    // The synthetic "All" row is first in the traversal order; the second
    // Tab moves focus to Alpha so the assertion covers a named category.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final alpha = find.bySemanticsLabel('Alpha');
    expect(alpha, findsOneWidget);
    expect(
      find.descendant(
        of: alpha,
        matching: find.byKey(const ValueKey('category-sidebar-focus-ring')),
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selectedGroups, ['Alpha']);

    semantics.dispose();
  });

  testWidgets('directional navigation does not add decorative focus stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapDirectional(
        CategorySidebar(
          groups: const ['Alpha', 'Beta'],
          selectedGroup: 'Alpha',
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.byType(FocusableActionDetector), findsNothing);
  });
}
