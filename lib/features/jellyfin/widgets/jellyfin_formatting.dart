import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';

/// Formats Jellyfin ticks (100 ns units) as a compact runtime label.
String jellyfinRuntimeLabel(AppLocalizations l10n, int runTimeTicks) {
  final minutes =
      runTimeTicks ~/ Duration.microsecondsPerSecond ~/ 10 ~/ 60;
  if (minutes < 60) {
    return l10n.jellyfinRuntimeMinutes(minutes);
  }
  return l10n.jellyfinRuntimeHours(minutes ~/ 60, minutes % 60);
}

/// Builds the stable `S{season} E{episode}` label; falls back to the episode
/// number alone when no season is present.
String jellyfinSeasonEpisodeLabel(
  AppLocalizations l10n, {
  required int? season,
  required int? episode,
}) {
  if (season != null && episode != null) {
    return l10n.jellyfinSeasonEpisodeLabel(season, episode);
  }
  if (episode != null) {
    return l10n.jellyfinEpisodeLabel(episode);
  }
  return '';
}

/// Groups episodes by season number in ascending order, sorted by episode
/// number within each season. Episodes without a season number land in
/// season zero.
Map<int, List<JellyfinItem>> jellyfinGroupEpisodesBySeason(
  List<JellyfinItem> episodes,
) {
  final bySeason = <int, List<JellyfinItem>>{};
  for (final episode in episodes) {
    final season = episode.seasonNumber ?? 0;
    bySeason.putIfAbsent(season, () => []).add(episode);
  }
  for (final seasonEpisodes in bySeason.values) {
    seasonEpisodes.sort(
      (a, b) =>
          (a.episodeNumber ?? 999999).compareTo(b.episodeNumber ?? 999999),
    );
  }
  final entries = bySeason.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return {for (final entry in entries) entry.key: entry.value};
}
