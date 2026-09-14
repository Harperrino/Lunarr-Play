import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/search/search_index_repository.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/app/composition/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/app/widgets/global_search_field.dart';

final _searchResults = const GlobalSearchResults(
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

SearchIndexBuildState _state({
  required int ready,
  required int building,
  required int failed,
}) {
  final playlists = <SearchIndexPlaylistState>[];
  for (var id = 0; id < ready; id++) {
    playlists.add(
      SearchIndexPlaylistState(
        playlistId: id,
        playlistName: 'Ready $id',
        status: SearchIndexStatus.ready,
        documentCount: 1,
        syncRevision: 1,
      ),
    );
  }
  for (var id = ready; id < ready + building; id++) {
    playlists.add(
      SearchIndexPlaylistState(
        playlistId: id,
        playlistName: 'Building $id',
        status: SearchIndexStatus.building,
        documentCount: 0,
        syncRevision: 0,
      ),
    );
  }
  for (var id = ready + building; id < ready + building + failed; id++) {
    playlists.add(
      SearchIndexPlaylistState(
        playlistId: id,
        playlistName: 'Failed $id',
        status: SearchIndexStatus.failed,
        documentCount: 0,
        syncRevision: 0,
      ),
    );
  }
  return SearchIndexBuildState(playlists: playlists);
}

Future<void> _pumpSearch(
  WidgetTester tester,
  SearchIndexBuildState indexState, {
  SearchIndexRepository? repository,
}) async {
  final overrides = <Override>[
    globalSearchResultsProvider.overrideWithValue(_searchResults),
    globalSearchResultsAsyncProvider.overrideWith(
      (ref) async => _searchResults,
    ),
    searchResultsAsyncProvider.overrideWithValue(AsyncData(_searchResults)),
    searchIndexBuildStateProvider.overrideWith(
      (ref) => Stream.value(indexState),
    ),
    if (repository != null)
      searchIndexRepositoryProvider.overrideWithValue(repository),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 640, child: GlobalSearchField()),
          ),
        ),
      ),
    ),
  );
  await tester.enterText(find.byType(EditableText), 'News');
  await tester.pump(const Duration(milliseconds: 140));
}

void main() {
  testWidgets('building index is visible in field semantics and overlay', (
    tester,
  ) async {
    await _pumpSearch(tester, _state(ready: 2, building: 2, failed: 0));

    expect(find.byTooltip('Search index: 2 of 4 playlists'), findsOneWidget);
    expect(find.text('Search index: 2 of 4 playlists'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Search index: 2 of 4 playlists'),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('failed index is not building and exposes retry', (tester) async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    final repository = SearchIndexRepository(database);
    addTearDown(() async {
      await repository.dispose();
      await database.close();
    });
    await _pumpSearch(
      tester,
      _state(ready: 3, building: 0, failed: 1),
      repository: repository,
    );

    expect(find.byTooltip('Search index: 3 of 4 playlists'), findsNothing);
    expect(find.text('1 playlist is not fully indexed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
