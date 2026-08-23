import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_episode_navigation.dart';

JellyfinItem episode(
  String id, {
  int? season = 1,
  int? number,
  String? seriesId = 'series-1',
}) => JellyfinItem(
  id: id,
  name: id,
  type: 'Episode',
  seriesId: seriesId,
  seasonNumber: season,
  episodeNumber: number,
);

void main() {
  test('returns the unique next episode across a season boundary', () {
    final current = episode('s1e2', number: 2);
    final next = jellyfinUnambiguousNextEpisode([
      episode('s2e1', season: 2, number: 1),
      current,
      episode('s1e1', number: 1),
    ], current);

    expect(next?.id, 's2e1');
  });

  test('returns no endcard candidate for ambiguous metadata', () {
    final current = episode('s1e1', number: 1);
    expect(
      jellyfinUnambiguousNextEpisode([
        current,
        episode('missing', season: null, number: 2),
      ], current),
      isNull,
    );
    expect(
      jellyfinUnambiguousNextEpisode([
        current,
        episode('duplicate', number: 1),
      ], current),
      isNull,
    );
    expect(
      jellyfinUnambiguousNextEpisode([
        current,
        episode('foreign', number: 2, seriesId: 'series-2'),
      ], current),
      isNull,
    );
    expect(
      jellyfinUnambiguousNextEpisode([episode('other', number: 2)], current),
      isNull,
    );
  });

  test('returns no candidate for the last episode', () {
    final current = episode('last', number: 3);
    expect(
      jellyfinUnambiguousNextEpisode([
        episode('first', number: 1),
        current,
      ], current),
      isNull,
    );
  });
}
