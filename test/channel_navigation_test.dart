import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/channel_navigation.dart';

Channel _channel(int id, String name) {
  return Channel(
    id: id,
    playlistId: 1,
    name: name,
    streamUrl: 'http://example.com/$id.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
  );
}

void main() {
  group('navigateChannel', () {
    final channels = [
      _channel(1, 'Alpha'),
      _channel(2, 'Beta'),
      _channel(3, 'Gamma'),
    ];

    test('returns null for empty channel list', () {
      expect(
        navigateChannel(channels: const [], selected: null, direction: 1),
        isNull,
      );
    });

    test('wraps forward from last to first channel', () {
      final selected = channels.last;
      final next = navigateChannel(
        channels: channels,
        selected: selected,
        direction: 1,
      );
      expect(next?.id, channels.first.id);
    });

    test('wraps backward from first to last channel', () {
      final selected = channels.first;
      final prev = navigateChannel(
        channels: channels,
        selected: selected,
        direction: -1,
      );
      expect(prev?.id, channels.last.id);
    });

    test(
      'selects first channel when none is selected and direction is forward',
      () {
        final next = navigateChannel(
          channels: channels,
          selected: null,
          direction: 1,
        );
        expect(next?.id, channels.first.id);
      },
    );

    test('returns null when selected channel is not in the filtered list', () {
      final orphan = _channel(99, 'Orphan');
      expect(
        navigateChannel(channels: channels, selected: orphan, direction: 1),
        isNull,
      );
    });

    test('moves to adjacent channel in the given direction', () {
      final next = navigateChannel(
        channels: channels,
        selected: channels[1],
        direction: 1,
      );
      expect(next?.id, channels[2].id);

      final prev = navigateChannel(
        channels: channels,
        selected: channels[1],
        direction: -1,
      );
      expect(prev?.id, channels[0].id);
    });
  });
}
