import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_shelf.dart';

void main() {
  testWidgets('vertical mouse wheel scrolls the feed, not the shelf', (
    tester,
  ) async {
    final items = List<DiscoveryMediaItem>.generate(
      12,
      (index) => DiscoveryMediaItem(
        id: index + 1,
        mediaType: DiscoveryMediaType.movie,
        title: 'Movie $index',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DiscoveryShelfView(
                    shelf: DiscoveryShelf(
                      kind: DiscoveryShelfKind.popularMovies,
                      items: items,
                    ),
                    onSelect: (_) {},
                    onShowAll: () {},
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byType(ListView);
    final horizontal = tester.state<ScrollableState>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
    final vertical = tester.state<ScrollableState>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(horizontal.position.pixels, 0);
    expect(vertical.position.pixels, 0);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(list),
        scrollDelta: const Offset(0, 180),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pumpAndSettle();

    expect(horizontal.position.pixels, 0);
    expect(vertical.position.pixels, greaterThan(0));
    expect(find.text('Show all'), findsOneWidget);
  });

  testWidgets('shelf arrows retain explicit horizontal navigation', (
    tester,
  ) async {
    final items = List<DiscoveryMediaItem>.generate(
      12,
      (index) => DiscoveryMediaItem(
        id: index + 1,
        mediaType: DiscoveryMediaType.movie,
        title: 'Movie $index',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: DiscoveryShelfView(
              shelf: DiscoveryShelf(
                kind: DiscoveryShelfKind.popularMovies,
                items: items,
              ),
              onSelect: (_) {},
              onShowAll: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final horizontal = tester.state<ScrollableState>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );

    await tester.tap(find.byTooltip('Scroll shelf forward'));
    await tester.pumpAndSettle();

    expect(horizontal.position.pixels, greaterThan(0));
    expect(find.byTooltip('Scroll shelf backward'), findsOneWidget);
  });
}
