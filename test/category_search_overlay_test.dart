import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/features/xtream/providers/media_library_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/vod_providers.dart';
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

ProviderContainer _container() => ProviderContainer(
  overrides: [globalSearchResultsProvider.overrideWithValue(_results())],
);

ProviderContainer _channelContainer() {
  final channel = Channel(
    id: 42,
    playlistId: 7,
    name: 'News HD',
    streamUrl: 'https://example.invalid/news.m3u8',
    providerOrder: 0,
    groupName: 'News',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
  );
  return ProviderContainer(
    overrides: [
      globalSearchResultsProvider.overrideWithValue(
        GlobalSearchResults(
          channels: [
            ChannelSearchResult(
              channel: channel,
              playlistId: 7,
              playlistName: 'Main playlist',
              categoryName: 'News',
              resolvedEpgChannelId: 'epg-news',
            ),
          ],
          categories: const [],
        ),
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
        home: const Scaffold(
          body: SizedBox(width: 640, child: GlobalSearchField()),
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(EditableText), 'News');
  await tester.pump();
}

void main() {
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

    expect(find.text('Alle'), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.text('Kategorien'), findsOneWidget);
    expect(find.text('News HD'), findsOneWidget);
    expect(find.text('News · Main playlist'), findsOneWidget);
    expect(find.text('Jetzt: Tagesschau'), findsOneWidget);
  });
}
