import 'package:m3uxtream_player/core/constants/filter_constants.dart';

const int categorySearchResultLimit = 12;

enum CategorySearchTarget { live, movies, series }

extension CategorySearchTargetLabels on CategorySearchTarget {
  String get label => switch (this) {
    CategorySearchTarget.live => 'Live TV',
    CategorySearchTarget.movies => 'Movies',
    CategorySearchTarget.series => 'Series',
  };
}

class CategorySearchResult {
  const CategorySearchResult({
    required this.target,
    required this.categoryName,
    required this.playlistId,
    required this.playlistName,
    required this.isPinned,
  });

  final CategorySearchTarget target;
  final String categoryName;
  final int playlistId;
  final String playlistName;
  final bool isPinned;

  String get targetLabel => target.label;
  String get visibleLabel => '$categoryName · $targetLabel · $playlistName';
  String get metadataLabel => '$targetLabel · $playlistName';
}

class _ScoredCategorySearchResult {
  const _ScoredCategorySearchResult({
    required this.result,
    required this.relevance,
  });

  final CategorySearchResult result;
  final int relevance;
}

List<CategorySearchResult> matchCategorySearchResults({
  required String query,
  required Iterable<CategorySearchResult> candidates,
  int limit = categorySearchResultLimit,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty || limit <= 0) return const [];

  final scored = <_ScoredCategorySearchResult>[];
  for (final candidate in candidates) {
    final normalizedName = candidate.categoryName.trim().toLowerCase();
    if (normalizedName.isEmpty || normalizedName == kAllGroupsFilter) continue;

    final relevance = normalizedName == normalizedQuery
        ? 0
        : normalizedName.startsWith(normalizedQuery)
        ? 1
        : normalizedName.contains(normalizedQuery)
        ? 2
        : null;
    if (relevance == null) continue;
    scored.add(
      _ScoredCategorySearchResult(result: candidate, relevance: relevance),
    );
  }

  scored.sort((a, b) {
    final relevance = a.relevance.compareTo(b.relevance);
    if (relevance != 0) return relevance;

    final pinned = (b.result.isPinned ? 1 : 0).compareTo(
      a.result.isPinned ? 1 : 0,
    );
    if (pinned != 0) return pinned;

    final name = a.result.categoryName.toLowerCase().compareTo(
      b.result.categoryName.toLowerCase(),
    );
    if (name != 0) return name;

    final playlist = a.result.playlistName.toLowerCase().compareTo(
      b.result.playlistName.toLowerCase(),
    );
    if (playlist != 0) return playlist;

    final target = a.result.target.index.compareTo(b.result.target.index);
    if (target != 0) return target;
    return a.result.playlistId.compareTo(b.result.playlistId);
  });

  return scored
      .take(limit)
      .map((entry) => entry.result)
      .toList(growable: false);
}
