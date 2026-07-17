import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';

Widget _wrap(double width, Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  ),
);

ShellCommandArea _allSlots() => ShellCommandArea(
  title: 'Library',
  count: '42 items',
  supportingText: 'Browse the active catalogue without losing your place.',
  source: const OutlinedButton(onPressed: null, child: Text('Source')),
  search: const SizedBox(
    width: 260,
    height: 40,
    child: TextField(decoration: InputDecoration(hintText: 'Search')),
  ),
  actions: Wrap(
    spacing: 8,
    children: const [
      OutlinedButton(onPressed: null, child: Text('Filter')),
      FilledButton(onPressed: null, child: Text('Add')),
    ],
  ),
);

void main() {
  testWidgets('all slots stack without overflow on compact widths', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(719, _allSlots()));

    expect(find.byKey(ShellCommandArea.titleKey), findsOneWidget);
    expect(find.byKey(ShellCommandArea.countKey), findsOneWidget);
    expect(find.byKey(ShellCommandArea.supportingTextKey), findsOneWidget);
    expect(find.byKey(ShellCommandArea.searchKey), findsOneWidget);
    expect(find.byKey(ShellCommandArea.sourceKey), findsOneWidget);
    expect(find.byKey(ShellCommandArea.actionsKey), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(ShellCommandArea.supportingTextKey))
          .maxLines,
      2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all slots wrap horizontally on expanded and wide widths', (
    tester,
  ) async {
    for (final width in [1200.0, 1600.0]) {
      await tester.pumpWidget(_wrap(width, _allSlots()));

      final titleCenter = tester.getCenter(
        find.byKey(ShellCommandArea.titleKey),
      );
      final searchCenter = tester.getCenter(
        find.byKey(ShellCommandArea.searchKey),
      );
      expect(searchCenter.dx, greaterThan(titleCenter.dx));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'stacks search when medium width cannot preserve side corridors',
    (tester) async {
      await tester.pumpWidget(_wrap(720, _allSlots()));

      final titleRect = tester.getRect(find.byKey(ShellCommandArea.titleKey));
      final searchRect = tester.getRect(find.byKey(ShellCommandArea.searchKey));
      expect(searchRect.top, greaterThanOrEqualTo(titleRect.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('omits absent optional slots without placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(600, const ShellCommandArea(title: 'Settings')),
    );

    expect(find.byKey(ShellCommandArea.titleKey), findsOneWidget);
    expect(find.byKey(ShellCommandArea.countKey), findsNothing);
    expect(find.byKey(ShellCommandArea.supportingTextKey), findsNothing);
    expect(find.byKey(ShellCommandArea.searchKey), findsNothing);
    expect(find.byKey(ShellCommandArea.sourceKey), findsNothing);
    expect(find.byKey(ShellCommandArea.actionsKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'centers desktop search in the header band before the count slot',
    (tester) async {
      const search = SizedBox(
        height: GlobalSearchField.fieldHeight,
        child: ColoredBox(color: Colors.blue),
      );

      Future<void> pumpCommandArea({
        required bool withCount,
        double scale = 1,
      }) {
        return tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 1200,
                    child: ShellCommandArea(
                      title: 'Library',
                      count: withCount ? '42 items' : null,
                      search: search,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await pumpCommandArea(withCount: false);
      expect(tester.getTopLeft(find.byKey(ShellCommandArea.searchKey)).dy, 0);

      await pumpCommandArea(withCount: true);
      expect(tester.getTopLeft(find.byKey(ShellCommandArea.searchKey)).dy, 0);

      await pumpCommandArea(withCount: true, scale: 2);
      expect(
        tester.getTopLeft(find.byKey(ShellCommandArea.searchKey)).dy,
        closeTo((72 * 2 - GlobalSearchField.fieldHeight) / 2, 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
