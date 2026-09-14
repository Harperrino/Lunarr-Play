import 'dart:collection';

import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';

/// Immutable, consistently ordered projection of a Jellyfin series episode
/// response.
///
/// Jellyfin remains the source of truth. Missing season numbers are grouped
/// into season zero so incomplete metadata stays reachable instead of being
/// discarded.
class JellyfinEpisodeCatalog {
  JellyfinEpisodeCatalog._({
    required List<JellyfinItem> episodes,
    required Map<int, List<JellyfinItem>> episodesBySeason,
  }) : episodes = UnmodifiableListView(episodes),
       episodesBySeason = UnmodifiableMapView({
         for (final entry in episodesBySeason.entries)
           entry.key: UnmodifiableListView(entry.value),
       });

  factory JellyfinEpisodeCatalog.fromEpisodes(Iterable<JellyfinItem> source) {
    final episodes = source.toList(growable: false)..sort(compareEpisodes);
    final grouped = <int, List<JellyfinItem>>{};
    for (final episode in episodes) {
      grouped.putIfAbsent(episode.seasonNumber ?? 0, () => []).add(episode);
    }
    return JellyfinEpisodeCatalog._(
      episodes: episodes,
      episodesBySeason: grouped,
    );
  }

  final UnmodifiableListView<JellyfinItem> episodes;
  final UnmodifiableMapView<int, UnmodifiableListView<JellyfinItem>>
  episodesBySeason;

  bool get isEmpty => episodes.isEmpty;

  List<int> get seasons => episodesBySeason.keys.toList(growable: false);

  List<JellyfinItem> episodesForSeason(int season) =>
      episodesBySeason[season] ?? const <JellyfinItem>[];

  int? seasonForItem(String itemId) {
    for (final entry in episodesBySeason.entries) {
      if (entry.value.any((episode) => episode.id == itemId)) {
        return entry.key;
      }
    }
    return null;
  }

  int? normalizedSeason(int? preferred) {
    if (preferred != null && episodesBySeason.containsKey(preferred)) {
      return preferred;
    }
    return episodesBySeason.isEmpty ? null : episodesBySeason.keys.first;
  }

  JellyfinItem? firstEpisodeForSeason(int? season) {
    if (season == null) return null;
    final episodes = episodesBySeason[season];
    return episodes == null || episodes.isEmpty ? null : episodes.first;
  }

  static int compareEpisodes(JellyfinItem left, JellyfinItem right) {
    final season = (left.seasonNumber ?? 0).compareTo(right.seasonNumber ?? 0);
    if (season != 0) return season;

    final leftEpisode = left.episodeNumber;
    final rightEpisode = right.episodeNumber;
    if (leftEpisode != null || rightEpisode != null) {
      if (leftEpisode == null) return 1;
      if (rightEpisode == null) return -1;
      final episode = leftEpisode.compareTo(rightEpisode);
      if (episode != 0) return episode;
    }

    final insensitive = left.name.toLowerCase().compareTo(
      right.name.toLowerCase(),
    );
    return insensitive != 0 ? insensitive : left.name.compareTo(right.name);
  }
}
