// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unnecessary_const

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/shell_sidebar.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_brand_mark.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: shellSidebarExpandedWidth,
          height: 720,
          child: child,
        ),
      ),
    ),
  );
}

void _expectFocusRing(WidgetTester tester, Finder control) {
  final ring = find.descendant(
    of: control,
    matching: find.byKey(const ValueKey('shell-sidebar-focus-ring')),
  );
  expect(ring, findsOneWidget);

  final decoration =
      tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
  final border = decoration.border! as Border;
  expect(border.top.width, 2);
  expect(border.top.color, AppStatusColors.dark.focus);

  final position = tester.widget<Positioned>(
    find.ancestor(of: ring, matching: find.byType(Positioned)),
  );
  expect(position.left, -4);
  expect(position.top, -4);
  expect(position.right, -4);
  expect(position.bottom, -4);
}

Widget _wrapWithWidth(double width, Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, height: 720, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('toggle exposes tooltip and does not select another tab', (
    tester,
  ) async {
    var toggleCount = 0;
    final tappedIndices = <int>[];

    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellVodTabIndex,
          debugModeEnabled: false,
          isExpanded: true,
          onTap: tappedIndices.add,
          onToggleExpanded: () => toggleCount++,
        ),
      ),
    );

    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shell-sidebar-brand-wordmark')),
      findsOneWidget,
    );
    expect(find.text('LUNARR One'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('shell-sidebar-brand-mark')),
      findsOneWidget,
    );
    expect(find.byKey(AppBrandMark.painterKey), findsOneWidget);
    final sidebarCenter = tester.getCenter(find.byType(ShellSidebar)).dx;
    final brandCenter = tester
        .getCenter(find.byKey(const ValueKey('shell-sidebar-brand')))
        .dx;
    final brandRect = tester.getRect(
      find.byKey(const ValueKey('shell-sidebar-brand')),
    );
    final collapseRect = tester.getRect(find.byTooltip('Collapse sidebar'));
    expect(brandCenter, lessThan(sidebarCenter));
    expect(brandRect.right, lessThanOrEqualTo(collapseRect.left - 16));
    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pump();

    expect(toggleCount, 1);
    expect(tappedIndices, isEmpty);
    expect(find.text('Mediathek'), findsOneWidget);
  });

  testWidgets('collapsed items retain tooltip semantics and active index', (
    tester,
  ) async {
    final tappedIndices = <int>[];

    await tester.pumpWidget(
      _wrapWithWidth(
        shellSidebarCollapsedWidth,
        ShellSidebar(
          activeIndex: shellSeriesTabIndex,
          debugModeEnabled: false,
          isExpanded: false,
          onTap: tappedIndices.add,
          onToggleExpanded: () {},
        ),
      ),
    );

    expect(find.byTooltip('Expand sidebar'), findsOneWidget);
    expect(find.byTooltip('Mediathek'), findsOneWidget);
    await tester.tap(find.byTooltip('Mediathek'));

    expect(tappedIndices, [shellMediaLibraryTabIndex]);
  });

  testWidgets('collapse rebuild retains the active tab without navigation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var isExpanded = true;
    final tappedIndices = <int>[];

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => ShellSidebar(
            activeIndex: shellSeriesTabIndex,
            debugModeEnabled: false,
            isExpanded: isExpanded,
            onTap: tappedIndices.add,
            onToggleExpanded: () => setState(() => isExpanded = !isExpanded),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Collapse sidebar'));
    await tester.pumpAndSettle();

    expect(isExpanded, isFalse);
    expect(tappedIndices, isEmpty);
    expect(find.byTooltip('Expand sidebar'), findsOneWidget);
    final library = find.bySemanticsLabel('Mediathek');
    expect(library, findsOneWidget);
    expect(
      tester.getSemantics(library),
      matchesSemantics(
        label: 'Mediathek',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('navigation rows expose Material 3 geometry and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellSeriesTabIndex,
          debugModeEnabled: false,
          isExpanded: true,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
      ),
    );

    final libraryItem = find.byKey(
      const ValueKey('shell-sidebar-item-$shellMediaLibraryTabIndex'),
    );
    expect(tester.getSize(libraryItem).height, shellSidebarNavigationRowHeight);
    final librarySemantics = find.bySemanticsLabel('Mediathek');
    expect(librarySemantics, findsOneWidget);
    expect(
      tester.getSemantics(librarySemantics),
      matchesSemantics(
        label: 'Mediathek',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('keyboard focus is visible and activates the collapse control', (
    tester,
  ) async {
    var toggles = 0;
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
      extensions: const <ThemeExtension<dynamic>>[AppStatusColors.dark],
    );

    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: false,
          isExpanded: true,
          onTap: (_) {},
          onToggleExpanded: () => toggles++,
        ),
        theme: theme,
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final toggle = find.byTooltip('Collapse sidebar');
    _expectFocusRing(tester, toggle);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(toggles, 1);
  });

  testWidgets('collapse transfers focus to the collapsed expand control', (
    tester,
  ) async {
    var isExpanded = true;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) => ShellSidebar(
            activeIndex: shellLiveTabIndex,
            debugModeEnabled: false,
            isExpanded: isExpanded,
            onTap: (_) {},
            onToggleExpanded: () => setState(() => isExpanded = !isExpanded),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<InkWell>(
            find.descendant(
              of: find.byTooltip('Collapse sidebar'),
              matching: find.byType(InkWell),
            ),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final expand = find.byTooltip('Expand sidebar');
    expect(isExpanded, isFalse);
    expect(expand, findsOneWidget);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: expand, matching: find.byType(InkWell)),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets('focused navigation rows retain their 48-pixel geometry', (
    tester,
  ) async {
    final theme = ThemeData.dark(useMaterial3: true).copyWith(
      extensions: const <ThemeExtension<dynamic>>[AppStatusColors.dark],
    );

    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellSeriesTabIndex,
          debugModeEnabled: false,
          isExpanded: true,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
        theme: theme,
      ),
    );

    for (var tab = 0; tab < 3; tab++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    final libraryItem = find.byKey(
      const ValueKey('shell-sidebar-item-$shellMediaLibraryTabIndex'),
    );
    expect(tester.getSize(libraryItem).height, shellSidebarNavigationRowHeight);
    _expectFocusRing(tester, libraryItem);
  });

  testWidgets('settings remains below primary navigation', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: true,
          isExpanded: true,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
      ),
    );

    final settingsY = tester.getCenter(find.text('Settings')).dy;
    final primaryItems = [
      'Live TV',
      'Mediathek',
      'Favorites',
      'Playlists',
      'EPG Guide',
      'Diagnostics / Logs',
    ];
    for (final label in primaryItems) {
      expect(tester.getCenter(find.text(label)).dy, lessThan(settingsY));
    }
    final shellHeight = tester.getSize(find.byType(Scaffold)).height;
    expect(
      tester
          .getBottomRight(
            find.byKey(
              const ValueKey('shell-sidebar-item-$shellSettingsTabIndex'),
            ),
          )
          .dy,
      closeTo(shellHeight - 12, 0.1),
    );
  });

  testWidgets('collapsed rail hides labels', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: true,
          isExpanded: false,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
      ),
    );

    expect(find.text('Live TV'), findsNothing);
    expect(find.text('Diagnostics / Logs'), findsNothing);
  });

  testWidgets('collapsed rail does not overflow in compact width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithWidth(
        shellSidebarCollapsedWidth,
        ShellSidebar(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: true,
          isExpanded: false,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded rail falls back to compact layout in very narrow width',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithWidth(
          55,
          ShellSidebar(
            activeIndex: shellLiveTabIndex,
            debugModeEnabled: true,
            isExpanded: true,
            onTap: (_) {},
            onToggleExpanded: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('M3U Xtream'), findsNothing);
      expect(find.text('Live TV'), findsNothing);
    },
  );

  testWidgets('expanded rail shows debug tab only when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: false,
          isExpanded: true,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
      ),
    );

    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('M3U Xtream'), findsNothing);
    expect(find.text('Diagnostics / Logs'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        ShellSidebar(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: true,
          isExpanded: true,
          onTap: (_) {},
          onToggleExpanded: () {},
        ),
      ),
    );

    expect(find.text('Diagnostics / Logs'), findsOneWidget);
  });

  testWidgets('standard shell chrome stays within tight width', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 540,
              height: 720,
              child: Row(
                children: [
                  SizedBox(
                    width: shellSidebarExpandedWidth,
                    child: ShellSidebar(
                      activeIndex: shellVodTabIndex,
                      debugModeEnabled: true,
                      isExpanded: true,
                      onTap: (_) {},
                      onToggleExpanded: () {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                'VOD Movies',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Browse movies from your active playlist - tap to play on the Live tab.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GlobalSearchField(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
