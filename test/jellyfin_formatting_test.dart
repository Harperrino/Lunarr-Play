import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('jellyfinRuntimeLabel', () {
    test('formats minutes below one hour', () {
      expect(jellyfinRuntimeLabel(l10n, 45 * 60 * 10000000), '45 min');
    });

    test('formats hours and minutes', () {
      expect(jellyfinRuntimeLabel(l10n, 84 * 60 * 10000000), '1 h 24 min');
      expect(jellyfinRuntimeLabel(l10n, 150 * 60 * 10000000), '2 h 30 min');
    });
  });

  group('jellyfinSeasonEpisodeLabel', () {
    test('builds SxxExx when both numbers exist', () {
      expect(
        jellyfinSeasonEpisodeLabel(l10n, season: 2, episode: 7),
        'S2 E7',
      );
    });

    test('falls back to the episode number', () {
      expect(jellyfinSeasonEpisodeLabel(l10n, season: null, episode: 3), 'Episode 3');
      expect(jellyfinSeasonEpisodeLabel(l10n, season: 1, episode: null), '');
    });
  });

  group('jellyfinGroupEpisodesBySeason', () {
    test('groups and sorts seasons ascending', () {
      final episodes = [
        jellyfinEpisode(season: 2, episode: 2),
        jellyfinEpisode(season: 1, episode: 1),
        jellyfinEpisode(season: 2, episode: 1),
      ];

      final grouped = jellyfinGroupEpisodesBySeason(episodes);

      expect(grouped.keys, [1, 2]);
      expect(grouped[1]!.single.episodeNumber, 1);
      expect(grouped[2]!.map((e) => e.episodeNumber), [1, 2]);
    });

    test('keeps episodes without a season in season zero', () {
      final grouped = jellyfinGroupEpisodesBySeason([
        jellyfinEpisode(season: null, episode: 4),
      ]);
      expect(grouped.keys, [0]);
    });
  });
}

JellyfinItem jellyfinEpisode({int? season, int? episode}) {
  return JellyfinItem(
    id: 'ep-$season-$episode',
    name: 'Episode',
    type: 'Episode',
    seasonNumber: season,
    episodeNumber: episode,
  );
}
