import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';

Channel _seriesChannel({int id = 1, String name = 'Show', String? groupName}) {
  return Channel(
    id: id,
    playlistId: 1,
    streamId: '9001',
    name: name,
    logo: null,
    groupName: groupName,
    tvgId: null,
    streamUrl: 'http://host/series/user/pass/9001',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'series',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}

void main() {
  group('filterSeriesChannelsByGroup', () {
    final channels = [
      _seriesChannel(id: 1, name: 'Drama Show', groupName: 'Drama'),
      _seriesChannel(id: 2, name: 'Comedy Show', groupName: 'Comedy'),
      _seriesChannel(id: 3, name: 'No Genre'),
    ];

    test('returns all channels for kAllGroupsFilter', () {
      expect(filterSeriesChannelsByGroup(channels, kAllGroupsFilter).length, 3);
    });

    test('filters by genre name', () {
      final filtered = filterSeriesChannelsByGroup(channels, 'Drama');
      expect(filtered.length, 1);
      expect(filtered.single.name, 'Drama Show');
    });

    test('filters uncategorized entries', () {
      final filtered = filterSeriesChannelsByGroup(channels, 'Uncategorized');
      expect(filtered.length, 1);
      expect(filtered.single.name, 'No Genre');
    });
  });

  group('groupEpisodesBySeason', () {
    test('groups and sorts episodes by season and number', () {
      final episodes = [
        const ParsedSeriesEpisode(
          episodeId: '2',
          title: 'Ep 2',
          streamUrl: 'http://example.com/2.mp4',
          season: 1,
          episodeNum: 2,
        ),
        const ParsedSeriesEpisode(
          episodeId: '1',
          title: 'Ep 1',
          streamUrl: 'http://example.com/1.mp4',
          season: 1,
          episodeNum: 1,
        ),
        const ParsedSeriesEpisode(
          episodeId: '3',
          title: 'S2E1',
          streamUrl: 'http://example.com/3.mp4',
          season: 2,
          episodeNum: 1,
        ),
      ];

      final grouped = groupEpisodesBySeason(episodes);
      expect(grouped.keys.toList(), [1, 2]);
      expect(grouped[1]!.map((e) => e.episodeNum).toList(), [1, 2]);
      expect(grouped[2]!.single.title, 'S2E1');
    });
  });

  group('formatEpisodeSubtitle', () {
    test('formats season and episode numbers', () {
      const episode = ParsedSeriesEpisode(
        episodeId: '1',
        title: 'Pilot',
        streamUrl: 'http://example.com/1.mp4',
        season: 1,
        episodeNum: 3,
      );
      expect(formatEpisodeSubtitle(episode), 'S01E03');
    });

    test('falls back to title without season metadata', () {
      const episode = ParsedSeriesEpisode(
        episodeId: '1',
        title: 'Direct Play',
        streamUrl: 'http://example.com/show.mp4',
      );
      expect(formatEpisodeSubtitle(episode), 'Direct Play');
    });
  });
}
