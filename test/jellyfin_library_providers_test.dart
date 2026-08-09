import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';

import 'jellyfin_test_helpers.dart';

ProviderContainer _container({bool failResume = false, bool failViews = false}) {
  return ProviderContainer(
    overrides: [
      ...jellyfinTestOverrides(
        transport: jellyfinHappyTransport(
          failResume: failResume,
          failViews: failViews,
        ),
      ),
    ],
  );
}

void main() {
  test('home data loads all sections with libraries', () async {
    final container = _container();
    addTearDown(container.dispose);

    final home = await container.read(jellyfinHomeDataProvider.future);

    expect(home.libraries, hasLength(2));
    expect(home.resumeItems, hasLength(1));
    expect(home.nextUpItems, hasLength(1));
    expect(home.latestItems, hasLength(1));
  });

  test('a broken resume endpoint degrades only that section', () async {
    final container = _container(failResume: true);
    addTearDown(container.dispose);

    final home = await container.read(jellyfinHomeDataProvider.future);

    expect(home.resumeItems, isEmpty);
    expect(home.nextUpItems, hasLength(1));
    expect(home.latestItems, hasLength(1));
    expect(home.libraries, hasLength(2));
  });

  test('a broken library list fails the home request visibly', () async {
    final container = _container(failViews: true);
    addTearDown(container.dispose);

    await expectLater(
      container.read(jellyfinHomeDataProvider.future),
      throwsA(isA<Object>()),
    );
    expect(container.read(jellyfinHomeDataProvider).hasError, isTrue);
  });

  test('library items and series episodes load per family', () async {
    final container = _container();
    addTearDown(container.dispose);

    final items = await container.read(
      jellyfinLibraryItemsProvider('library-1').future,
    );
    expect(items, hasLength(2));
    expect(items.first, isA<JellyfinItem>());

    final episodes = await container.read(
      jellyfinSeriesEpisodesProvider('series-1').future,
    );
    expect(episodes, hasLength(2));
    expect(episodes.first.seasonNumber, 1);
  });

  test('item detail loads for a single item id', () async {
    final container = _container();
    addTearDown(container.dispose);

    final detail = await container.read(
      jellyfinItemDetailProvider('movie-1').future,
    );
    expect(detail.id, 'movie-1');
    expect(detail.name, 'Test Movie');
  });

  test('the view stack navigates home → library → details → back', () {
    final container = _container();
    addTearDown(container.dispose);

    expect(container.read(jellyfinViewStackProvider), const [
      JellyfinHomeRoute(),
    ]);

    final stackNotifier = container.read(jellyfinViewStackProvider.notifier);
    stackNotifier.state = const [
      JellyfinHomeRoute(),
      JellyfinLibraryRoute(library: JellyfinLibrary(id: 'library-1', name: 'Movies')),
    ];
    expect(
      container.read(jellyfinViewStackProvider).last,
      isA<JellyfinLibraryRoute>(),
    );

    stackNotifier.state = [
      ...container.read(jellyfinViewStackProvider),
      JellyfinDetailsRoute(item: JellyfinItem.fromJson(jellyfinMovieJson())),
    ];
    expect(
      container.read(jellyfinViewStackProvider).last,
      isA<JellyfinDetailsRoute>(),
    );

    stackNotifier.state = container
        .read(jellyfinViewStackProvider)
        .sublist(0, 1);
    expect(container.read(jellyfinViewStackProvider), const [
      JellyfinHomeRoute(),
    ]);
  });

  testWidgets('sidebar route helpers replace browse paths and preserve context', (
    tester,
  ) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, widgetRef, child) {
            ref = widgetRef;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const library = JellyfinLibrary(
      id: 'library-1',
      name: 'Movies',
      collectionType: 'movies',
    );
    jellyfinSelectLibrary(ref, library);
    final selectedStack = ref.read(jellyfinViewStackProvider);
    expect(selectedStack, hasLength(2));
    expect(selectedStack.first, isA<JellyfinHomeRoute>());
    expect(selectedStack.last, isA<JellyfinLibraryRoute>());
    expect((selectedStack.last as JellyfinLibraryRoute).library, library);
    expect(
      jellyfinSelectedLibrary(ref.read(jellyfinViewStackProvider)),
      library,
    );

    jellyfinOpenDetails(ref, JellyfinItem.fromJson(jellyfinMovieJson()));
    jellyfinOpenPlayer(ref, JellyfinItem.fromJson(jellyfinMovieJson()));
    expect(ref.read(jellyfinViewStackProvider).last, isA<JellyfinPlayerRoute>());
    jellyfinGoBack(ref);
    expect(ref.read(jellyfinViewStackProvider).last, isA<JellyfinDetailsRoute>());

    jellyfinSelectOverview(ref);
    expect(ref.read(jellyfinViewStackProvider), const [JellyfinHomeRoute()]);
    expect(jellyfinSelectedLibrary(ref.read(jellyfinViewStackProvider)), isNull);
  });
}
