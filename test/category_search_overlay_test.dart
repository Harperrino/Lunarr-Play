import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/providers/app_shell_state_providers.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';
import 'package:m3uxtream_player/app/composition/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/app/widgets/global_search_field.dart';
import 'package:m3uxtream_player/features/xtream/providers/media_library_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/providers/vod_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

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
    CategorySearchResult(
      target: CategorySearchTarget.movies,
      categoryName: 'News',
      playlistId: 1,
      playlistName: 'Main',
      isPinned: true,
    ),
    CategorySearchResult(
      target: CategorySearchTarget.series,
      categoryName: 'News',
      playlistId: 1,
      playlistName: 'Main',
      isPinned: false,
    ),
  ],
);

ProviderContainer _container({
  GlobalSearchResults? results,
  AsyncValue<GlobalSearchResults>? resultState,
}) => ProviderContainer(
  overrides: [
    globalSearchResultsProvider.overrideWithValue(results ?? _results()),
    globalSearchResultsAsyncProvider.overrideWith((ref) async {
      return results ?? _results();
    }),
    searchIndexBuildStateProvider.overrideWith(
      (ref) => Stream.value(const SearchIndexBuildState.empty()),
    ),
    if (resultState != null)
      searchResultsAsyncProvider.overrideWithValue(resultState),
  ],
);

ProviderContainer _channelContainer() {
  return ProviderContainer(
    overrides: [
      globalSearchResultsProvider.overrideWithValue(
        GlobalSearchResults(
          channels: [
            ChannelSearchResult(
              entry: const SearchCatalogEntry(
                channelId: 42,
                playlistId: 7,
                type: 'live',
                name: 'News HD',
                category: 'News',
                epgChannelId: 'epg-news',
              ),
              playlistId: 7,
              playlistName: 'Main playlist',
              categoryName: 'News',
              resolvedEpgChannelId: 'epg-news',
            ),
          ],
          categories: const [],
        ),
      ),
      globalSearchResultsAsyncProvider.overrideWith((ref) async {
        return GlobalSearchResults(
          channels: [
            ChannelSearchResult(
              entry: const SearchCatalogEntry(
                channelId: 42,
                playlistId: 7,
                type: 'live',
                name: 'News HD',
                category: 'News',
                epgChannelId: 'epg-news',
              ),
              playlistId: 7,
              playlistName: 'Main playlist',
              categoryName: 'News',
              resolvedEpgChannelId: 'epg-news',
            ),
          ],
          categories: const [],
        );
      }),
      searchIndexBuildStateProvider.overrideWith(
        (ref) => Stream.value(const SearchIndexBuildState.empty()),
      ),
      searchEpgLinesProvider.overrideWith(
        (ref) => Stream.value({42: const SearchEpgLine.current('Tagesschau')}),
      ),
    ],
  );
}

Future<void> _pumpSearch(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: const SizedBox.expand(),
              ),
              const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(width: 640, child: GlobalSearchField()),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(EditableText), 'News');
  await tester.pump(const Duration(milliseconds: 140));
}

void main() {
  testWidgets('filter tabs keep the overlay open and show an empty state', (
    tester,
  ) async {
    final container = _container(
      results: const GlobalSearchResults(channels: [], categories: []),
      resultState: const AsyncData(
        GlobalSearchResults(channels: [], categories: []),
      ),
    );
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    await tester.tap(find.text('Channels'));
    await tester.pump();

    expect(
      container.read(searchOverlayFilterProvider),
      SearchOverlayFilter.channels,
    );
    expect(container.read(searchOverlaySessionProvider).isOpen, isTrue);
    expect(
      find.byKey(const ValueKey('global-search-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('loading and error states stay mounted inside the overlay', (
    tester,
  ) async {
    final loadingContainer = _container(
      results: const GlobalSearchResults(channels: [], categories: []),
      resultState: const AsyncLoading<GlobalSearchResults>(),
    );
    addTearDown(loadingContainer.dispose);
    await _pumpSearch(tester, loadingContainer);
    expect(
      find.byKey(const ValueKey('global-search-loading-state')),
      findsOneWidget,
    );

    final errorContainer = _container(
      results: const GlobalSearchResults(channels: [], categories: []),
      resultState: AsyncValue.error(
        StateError('search unavailable'),
        StackTrace.current,
      ),
    );
    addTearDown(errorContainer.dispose);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpSearch(tester, errorContainer);
    expect(
      find.byKey(const ValueKey('global-search-error-state')),
      findsOneWidget,
    );
  });

  testWidgets('outside tap and clear close the overlay', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    await tester.tapAt(const Offset(700, 550));
    await tester.pump();
    expect(container.read(searchOverlaySessionProvider).isOpen, isFalse);
    expect(container.read(globalSearchQueryProvider), 'News');

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(container.read(globalSearchQueryProvider), isEmpty);
    expect(container.read(searchOverlaySessionProvider).isOpen, isFalse);
  });

  testWidgets('shows category hits below the focused search field', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    expect(
      find.byKey(const ValueKey('global-search-category-1-live-News')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('global-search-category-1-movies-News')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('global-search-category-1-series-News')),
      findsOneWidget,
    );
    expect(find.text('Live TV · Main'), findsOneWidget);
    expect(find.text('Movies · Main'), findsOneWidget);
  });

  testWidgets('mouse selection navigates without changing the query', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    await tester.tap(
      find.byKey(const ValueKey('global-search-category-1-live-News')),
    );
    await tester.pump();

    expect(container.read(activeSidebarIndexProvider), shellLiveTabIndex);
    expect(container.read(selectedGroupFilterProvider), 'News');
    expect(container.read(globalSearchQueryProvider), 'News');
    expect(
      find.byKey(const ValueKey('global-search-category-1-live-News')),
      findsNothing,
    );
  });

  testWidgets('arrow keys and Enter open the highlighted target', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      container.read(activeSidebarIndexProvider),
      shellMediaLibraryTabIndex,
    );
    expect(container.read(mediaLibraryTabProvider), mediaLibraryMoviesTabIndex);
    expect(container.read(selectedVodGroupFilterProvider), 'News');
    expect(container.read(globalSearchQueryProvider), 'News');
  });

  testWidgets('series selection opens the Series subtab and filter', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    await tester.tap(
      find.byKey(const ValueKey('global-search-category-1-series-News')),
    );
    await tester.pump();

    expect(
      container.read(activeSidebarIndexProvider),
      shellMediaLibraryTabIndex,
    );
    expect(container.read(mediaLibraryTabProvider), mediaLibrarySeriesTabIndex);
    expect(container.read(selectedSeriesGroupFilterProvider), 'News');
    expect(container.read(globalSearchQueryProvider), 'News');
  });

  testWidgets('Escape closes the overlay and keeps the search text', (
    tester,
  ) async {
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    expect(
      find.byKey(const ValueKey('global-search-category-1-live-News')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('global-search-category-1-live-News')),
      findsNothing,
    );
    expect(container.read(globalSearchQueryProvider), 'News');
  });

  testWidgets('category hits expose labelled button semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = _container();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);

    final result = find.bySemanticsLabel('News · Live TV · Main');
    expect(result, findsOneWidget);
    expect(
      tester.getSemantics(result),
      matchesSemantics(
        label: 'News · Live TV · Main',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('channel hits show tabs, source metadata and current EPG', (
    tester,
  ) async {
    final container = _channelContainer();
    addTearDown(container.dispose);
    await _pumpSearch(tester, container);
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Channels'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('News HD'), findsOneWidget);
    expect(find.text('News · Main playlist'), findsOneWidget);
    expect(find.text('Now: Tagesschau'), findsOneWidget);
  });
}
