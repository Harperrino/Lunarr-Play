@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/widgets/app_brand_mark.dart';
import 'package:m3uxtream_player/shared/widgets/custom_app_bar.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  testWidgets('title bar keeps a compact visual height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: CustomAppBar(onCloseRequested: () {})),
      ),
    );

    expect(
      tester.getSize(find.byType(CustomAppBar)),
      const Size(800, CustomAppBar.toolbarHeight),
    );
  });

  testWidgets('desktop drag area fills the toolbar height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: CustomAppBar(onCloseRequested: () {})),
      ),
    );

    final dragSizedBoxes = find.descendant(
      of: find.byType(DragToMoveArea),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.height == CustomAppBar.toolbarHeight,
      ),
    );

    expect(dragSizedBoxes, findsOneWidget);
  });

  testWidgets(
    'Material 3 top bar contains the global search without clipping',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: CustomAppBar(
                onCloseRequested: () {},
                search: const GlobalSearchField(),
              ),
            ),
          ),
        ),
      );

      final appBarRect = tester.getRect(find.byType(CustomAppBar));
      final searchRect = tester.getRect(find.byType(GlobalSearchField));
      expect(find.text('LUNARR One'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('window-bar-brand-mark')),
        findsOneWidget,
      );
      expect(find.byKey(AppBrandMark.painterKey), findsOneWidget);
      expect(searchRect.top, greaterThan(appBarRect.top));
      expect(searchRect.bottom, lessThan(appBarRect.bottom));
      expect(searchRect.height, GlobalSearchField.fieldHeight);
      expect(searchRect.center.dx, appBarRect.center.dx);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Material 3 LUNARR One top bar visual contract', (tester) async {
    tester.view.physicalSize = const Size(1440, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7BE6A2),
              brightness: Brightness.dark,
            ),
          ),
          home: Scaffold(
            appBar: CustomAppBar(
              onCloseRequested: () {},
              search: const GlobalSearchField(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(GlobalSearchField)).width, 520);

    await expectLater(
      find.byType(CustomAppBar),
      matchesGoldenFile('goldens/d15_lunarr_top_bar.png'),
    );
  });

  testWidgets('title bar close button requests shutdown callback', (
    tester,
  ) async {
    var requested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: CustomAppBar(
            onCloseRequested: () {
              requested = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(HoverWindowButton).last);
    await tester.pumpAndSettle();

    expect(requested, isTrue);
  });
}
