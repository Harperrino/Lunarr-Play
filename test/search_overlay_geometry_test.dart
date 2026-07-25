import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';

GlobalSearchResults _results() => const GlobalSearchResults(
  channels: [],
  categories: [
    CategorySearchResult(
      target: CategorySearchTarget.live,
      categoryName: 'News',
      playlistId: 1,
      playlistName: 'Main',
      isPinned: false,
    ),
  ],
);

ProviderContainer _container() => ProviderContainer(
  overrides: [
    globalSearchResultsProvider.overrideWithValue(_results()),
    globalSearchResultsAsyncProvider.overrideWith((ref) async => _results()),
    searchIndexBuildStateProvider.overrideWith(
      (ref) => Stream.value(const SearchIndexBuildState.empty()),
    ),
  ],
);

Future<void> _pumpSearch(
  WidgetTester tester,
  ProviderContainer container, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.enterText(find.byType(EditableText), 'News');
  await tester.pump(const Duration(milliseconds: 140));
  // Let the post-frame edge clamp settle.
  await tester.pump();
  await tester.pump();
}

Rect _overlayRect(WidgetTester tester) =>
    tester.getRect(find.byType(AppOverlaySurface));

Rect _barRect(WidgetTester tester) => tester.getRect(find.byType(SearchBar));

void main() {
  testWidgets('overlay width is capped at 480 dp below the search bar', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(
      tester,
      container,
      child: const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 640, child: GlobalSearchField()),
      ),
    );

    final overlay = _overlayRect(tester);
    final bar = _barRect(tester);
    expect(overlay.width, 480);
    expect(overlay.left, bar.left);
    expect(overlay.top, bar.bottom + 8);
  });

  testWidgets('overlay never exceeds the search-bar width', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(
      tester,
      container,
      child: const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 300, child: GlobalSearchField()),
      ),
    );

    final overlay = _overlayRect(tester);
    final bar = _barRect(tester);
    expect(overlay.width, bar.width);
    expect(overlay.top, bar.bottom + 8);
  });

  testWidgets('overlay keeps 12 dp distance to the right window edge', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(
      tester,
      container,
      child: const Padding(
        padding: EdgeInsets.only(left: 500),
        child: GlobalSearchField(),
      ),
    );

    final overlay = _overlayRect(tester);
    final bar = _barRect(tester);
    expect(bar.left, 500);
    expect(overlay.right, 800 - 12);
    expect(overlay.top, bar.bottom + 8);
  });

  testWidgets('window resize re-clamps the overlay but keeps the anchor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(
      tester,
      container,
      child: const Align(
        alignment: Alignment.topRight,
        child: SizedBox(width: 640, child: GlobalSearchField()),
      ),
    );

    var overlay = _overlayRect(tester);
    var bar = _barRect(tester);
    expect(overlay.left, bar.left);
    expect(overlay.top, bar.bottom + 8);

    // A narrower window shifts the bar left past the safe margin: the clamp
    // engages while the overlay stays glued to the bar's bottom edge.
    await tester.binding.setSurfaceSize(const Size(600, 600));
    await tester.pump();
    await tester.pump();

    overlay = _overlayRect(tester);
    bar = _barRect(tester);
    expect(overlay.left, 12);
    expect(overlay.right, lessThanOrEqualTo(600 - 12));
    expect(overlay.top, bar.bottom + 8);
  });

  testWidgets('a topbar width change keeps the overlay anchored', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);

    Future<void> pumpWithLeading(double leadingWidth) => _pumpSearch(
      tester,
      container,
      child: Row(
        children: [
          SizedBox(width: leadingWidth),
          const Expanded(child: GlobalSearchField()),
        ],
      ),
    );

    await pumpWithLeading(40);
    var overlay = _overlayRect(tester);
    var bar = _barRect(tester);
    expect(overlay.left, bar.left);
    expect(overlay.top, bar.bottom + 8);

    await pumpWithLeading(240);
    overlay = _overlayRect(tester);
    bar = _barRect(tester);
    expect(overlay.left, bar.left);
    expect(overlay.top, bar.bottom + 8);
  });

  testWidgets('the follower never lingers when the link is lost', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(
      tester,
      container,
      child: const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 640, child: GlobalSearchField()),
      ),
    );

    final follower = tester.widget<CompositedTransformFollower>(
      find.descendant(
        of: find.byType(OverlayPortal),
        matching: find.byType(CompositedTransformFollower),
      ),
    );
    expect(follower.showWhenUnlinked, isFalse);
    expect(follower.offset.dy, 8);
  });
}
