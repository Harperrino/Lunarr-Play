import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_episode_catalog.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';

void main() {
  JellyfinItem episode(String id, {int? season, int? number, String? name}) =>
      JellyfinItem(
        id: id,
        name: name ?? id,
        type: 'Episode',
        seasonNumber: season,
        episodeNumber: number,
      );

  test('sorts and groups episodes without mutating the source list', () {
    final source = [
      episode('s2e2', season: 2, number: 2),
      episode('s1e2', season: 1, number: 2),
      episode('s1e1', season: 1, number: 1),
    ];

    final catalog = JellyfinEpisodeCatalog.fromEpisodes(source);

    expect(catalog.seasons, [1, 2]);
    expect(catalog.episodes.map((item) => item.id), ['s1e1', 's1e2', 's2e2']);
    expect(source.map((item) => item.id), ['s2e2', 's1e2', 's1e1']);
  });

  test(
    'places missing season numbers in specials and missing episodes last',
    () {
      final catalog = JellyfinEpisodeCatalog.fromEpisodes([
        episode('unknown', name: 'Zulu'),
        episode('special-2', season: 0, number: 2),
        episode('special-1', season: 0, number: 1),
        episode('missing-number', season: 1, name: 'Alpha'),
        episode('known-number', season: 1, number: 3),
      ]);

      expect(catalog.seasons, [0, 1]);
      expect(catalog.episodesForSeason(0).map((item) => item.id), [
        'special-1',
        'special-2',
        'unknown',
      ]);
      expect(catalog.episodesForSeason(1).map((item) => item.id), [
        'known-number',
        'missing-number',
      ]);
    },
  );

  test('normalizes season and selection to the first available episode', () {
    final catalog = JellyfinEpisodeCatalog.fromEpisodes([
      episode('s1e2', season: 1, number: 2),
      episode('s2e3', season: 2, number: 3),
    ]);

    expect(catalog.normalizedSeason(null), 1);
    expect(catalog.normalizedSeason(99), 1);
    expect(catalog.normalizedSeason(2), 2);
    expect(catalog.firstEpisodeForSeason(2)?.id, 's2e3');
    expect(catalog.seasonForItem('s2e3'), 2);
    expect(catalog.seasonForItem('missing'), isNull);
  });

  test('empty catalog has no normalized selection', () {
    final catalog = JellyfinEpisodeCatalog.fromEpisodes(const []);

    expect(catalog.isEmpty, isTrue);
    expect(catalog.normalizedSeason(1), isNull);
    expect(catalog.firstEpisodeForSeason(1), isNull);
  });
}
