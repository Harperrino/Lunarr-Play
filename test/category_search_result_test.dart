import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';

List<CategorySearchResult> _candidates() => const [
  CategorySearchResult(
    target: CategorySearchTarget.live,
    categoryName: 'News Daily',
    playlistId: 1,
    playlistName: 'Main',
    isPinned: false,
  ),
  CategorySearchResult(
    target: CategorySearchTarget.live,
    categoryName: 'Sports News',
    playlistId: 1,
    playlistName: 'Main',
    isPinned: false,
  ),
  CategorySearchResult(
    target: CategorySearchTarget.live,
    categoryName: 'News',
    playlistId: 1,
    playlistName: 'Main',
    isPinned: false,
  ),
  CategorySearchResult(
    target: CategorySearchTarget.movies,
    categoryName: 'Newsreel',
    playlistId: 2,
    playlistName: 'Movies',
    isPinned: false,
  ),
];

void main() {
  test(
    'matches trimmed input case-insensitively by exact, prefix, then part',
    () {
      final results = matchCategorySearchResults(
        query: '  nEwS  ',
        candidates: _candidates(),
      );

      expect(results.map((result) => result.categoryName), [
        'News',
        'News Daily',
        'Newsreel',
        'Sports News',
      ]);
    },
  );

  test('pinned categories win only within the same relevance rank', () {
    final results = matchCategorySearchResults(
      query: 'news',
      candidates: [
        const CategorySearchResult(
          target: CategorySearchTarget.live,
          categoryName: 'News Daily',
          playlistId: 1,
          playlistName: 'Main',
          isPinned: false,
        ),
        const CategorySearchResult(
          target: CategorySearchTarget.live,
          categoryName: 'News Pinned',
          playlistId: 1,
          playlistName: 'Main',
          isPinned: true,
        ),
        const CategorySearchResult(
          target: CategorySearchTarget.live,
          categoryName: 'Sports News',
          playlistId: 1,
          playlistName: 'Main',
          isPinned: false,
        ),
      ],
    );

    expect(results.map((result) => result.categoryName), [
      'News Pinned',
      'News Daily',
      'Sports News',
    ]);
    expect(results.first.isPinned, isTrue);
  });

  test('keeps same-named categories separate by target area and playlist', () {
    final results = matchCategorySearchResults(
      query: 'news',
      candidates: const [
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
          playlistId: 2,
          playlistName: 'Movies',
          isPinned: false,
        ),
        CategorySearchResult(
          target: CategorySearchTarget.series,
          categoryName: 'News',
          playlistId: 3,
          playlistName: 'Series',
          isPinned: false,
        ),
      ],
    );

    expect(results, hasLength(3));
    expect(results.map((result) => result.target), [
      CategorySearchTarget.live,
      CategorySearchTarget.movies,
      CategorySearchTarget.series,
    ]);
    expect(results.map((result) => (result.target, result.playlistName)), [
      (CategorySearchTarget.live, 'Main'),
      (CategorySearchTarget.movies, 'Movies'),
      (CategorySearchTarget.series, 'Series'),
    ]);
  });

  test('uses only supplied visible groups and excludes the All sentinel', () {
    final results = matchCategorySearchResults(
      query: 'news',
      candidates: const [
        CategorySearchResult(
          target: CategorySearchTarget.live,
          categoryName: 'Visible News',
          playlistId: 1,
          playlistName: 'Main',
          isPinned: false,
        ),
        CategorySearchResult(
          target: CategorySearchTarget.movies,
          categoryName: '__all__',
          playlistId: 1,
          playlistName: 'Main',
          isPinned: false,
        ),
      ],
    );

    expect(results.map((result) => result.categoryName), ['Visible News']);
  });

  test('limits results to twelve with deterministic ordering', () {
    final results = matchCategorySearchResults(
      query: 'category',
      candidates: List<CategorySearchResult>.generate(
        20,
        (index) => CategorySearchResult(
          target: CategorySearchTarget.live,
          categoryName: 'Category $index',
          playlistId: 1,
          playlistName: 'Main',
          isPinned: false,
        ),
      ),
    );

    expect(results, hasLength(categorySearchResultLimit));
    expect(results.map((result) => result.categoryName).toList(), [
      'Category 0',
      'Category 1',
      'Category 10',
      'Category 11',
      'Category 12',
      'Category 13',
      'Category 14',
      'Category 15',
      'Category 16',
      'Category 17',
      'Category 18',
      'Category 19',
    ]);
  });
}
