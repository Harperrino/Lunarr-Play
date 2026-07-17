import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';

Channel _channel(String groupName, {String channelType = 'live'}) {
  return Channel(
    id: groupName.hashCode,
    playlistId: 1,
    name: groupName,
    streamUrl: 'http://example.com/$groupName.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: channelType,
    groupName: groupName,
  );
}

void main() {
  test(
    'prioritizePinnedGroups keeps pinned groups at the top in stored order',
    () {
      final groups = distinctSortedGroups([
        _channel('Alpha'),
        _channel('Beta'),
        _channel('Gamma'),
        _channel('Delta'),
      ]);

      expect(prioritizePinnedGroups(groups, ['Gamma', 'Alpha']), [
        'Gamma',
        'Alpha',
        'Beta',
        'Delta',
      ]);
    },
  );

  test(
    'prioritizePinnedGroups ignores missing pins and keeps remaining order',
    () {
      expect(
        prioritizePinnedGroups(['News', 'Movies'], ['Missing', 'Movies']),
        ['Movies', 'News'],
      );
    },
  );

  test(
    'hidden categories stay out while pinned categories keep their stored order',
    () {
      final allGroups = distinctSortedGroups([
        _channel('Alpha'),
        _channel('Beta'),
        _channel('Gamma'),
      ]);

      final hidden = visibleGroups(allGroups, {'Beta'});
      expect(prioritizePinnedGroups(hidden, ['Beta', 'Gamma']), [
        'Gamma',
        'Alpha',
      ]);
      expect(
        prioritizePinnedGroups(visibleGroups(allGroups, {}), ['Beta', 'Gamma']),
        ['Beta', 'Gamma', 'Alpha'],
      );
    },
  );

  test('filterChannelsByType isolates categories by content type', () {
    final channels = [
      _channel('Live News', channelType: 'live'),
      _channel('Shared', channelType: 'live'),
      _channel('Shared', channelType: 'vod'),
      _channel('Series One', channelType: 'series'),
    ];

    expect(distinctSortedGroups(filterChannelsByType(channels, 'live')), [
      'Live News',
      'Shared',
    ]);
    expect(distinctSortedGroups(filterChannelsByType(channels, 'vod')), [
      'Shared',
    ]);
    expect(distinctSortedGroups(filterChannelsByType(channels, 'series')), [
      'Series One',
    ]);
  });

  test('filterChannels combines group, visibility, search, and type', () {
    final channels = [
      _channel('News', channelType: 'live'),
      _channel('News Extra', channelType: 'vod'),
      _channel('Sports', channelType: 'live'),
      _channel('Hidden News', channelType: 'live'),
    ];

    final result = filterChannels(
      channels: channels,
      groupFilter: 'News',
      searchQuery: 'news',
      hiddenGroups: {'Hidden News'},
      channelType: 'live',
    );

    expect(result.map((channel) => channel.name), ['News']);
  });

  test('filterChannels returns the source list when no filter is active', () {
    final channels = [_channel('News'), _channel('Sports')];

    expect(identical(filterChannels(channels: channels), channels), isTrue);
  });
}
