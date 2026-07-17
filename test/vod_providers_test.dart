import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/vod_providers.dart';

Channel _vodChannel({int id = 1, String name = 'Movie', String? groupName}) {
  return Channel(
    id: id,
    playlistId: 1,
    streamId: '100',
    name: name,
    logo: null,
    groupName: groupName,
    tvgId: null,
    streamUrl: 'http://example.com/movie.mp4',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'vod',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}

void main() {
  group('filterVodChannelsByGroup', () {
    final channels = [
      _vodChannel(id: 1, name: 'Action Film', groupName: 'Action'),
      _vodChannel(id: 2, name: 'Comedy Film', groupName: 'Comedy'),
      _vodChannel(id: 3, name: 'No Genre'),
    ];

    test('returns all channels for kAllGroupsFilter', () {
      expect(filterVodChannelsByGroup(channels, kAllGroupsFilter).length, 3);
    });

    test('filters by genre name', () {
      final filtered = filterVodChannelsByGroup(channels, 'Action');
      expect(filtered.length, 1);
      expect(filtered.single.name, 'Action Film');
    });

    test('filters uncategorized entries', () {
      final filtered = filterVodChannelsByGroup(channels, 'Uncategorized');
      expect(filtered.length, 1);
      expect(filtered.single.name, 'No Genre');
    });
  });
}
