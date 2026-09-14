import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';

/// Returns the only safe autoplay successor for [current].
///
/// Autoplay intentionally degrades to no result when Jellyfin's episode
/// metadata cannot define one unique series order.
JellyfinItem? jellyfinUnambiguousNextEpisode(
  List<JellyfinItem> episodes,
  JellyfinItem current,
) {
  final seriesId = current.seriesId;
  if (!current.isEpisode || seriesId == null || seriesId.isEmpty) return null;

  final ids = <String>{};
  final positions = <(int, int)>{};
  var currentMatches = 0;
  for (final episode in episodes) {
    final season = episode.seasonNumber;
    final number = episode.episodeNumber;
    if (!episode.isEpisode || season == null || number == null) return null;
    if (episode.seriesId != null && episode.seriesId != seriesId) return null;
    if (!ids.add(episode.id) || !positions.add((season, number))) return null;
    if (episode.id == current.id) currentMatches++;
  }
  if (currentMatches != 1) return null;

  final ordered = [...episodes]
    ..sort((left, right) {
      final season = left.seasonNumber!.compareTo(right.seasonNumber!);
      return season != 0
          ? season
          : left.episodeNumber!.compareTo(right.episodeNumber!);
    });
  final currentIndex = ordered.indexWhere(
    (episode) => episode.id == current.id,
  );
  if (currentIndex < 0 || currentIndex + 1 >= ordered.length) return null;
  final next = ordered[currentIndex + 1];
  return next.id == current.id ? null : next;
}
