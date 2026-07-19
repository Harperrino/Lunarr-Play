import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/services/channel_sorting.dart';

Channel _channel(
  int id,
  String name, {
  required int providerOrder,
  String? channelNumber,
}) {
  return Channel(
    id: id,
    playlistId: 1,
    name: name,
    streamUrl: 'https://example.invalid/$id',
    providerOrder: providerOrder,
    channelNumber: channelNumber,
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
  );
}

void main() {
  test('provider default follows imported provider order', () {
    final channels = [
      _channel(1, 'Zulu', providerOrder: 0),
      _channel(2, 'Alpha', providerOrder: 1),
    ];

    expect(
      sortChannels(
        channels,
        ChannelSortMode.providerDefault,
      ).map((c) => c.name),
      ['Zulu', 'Alpha'],
    );
    expect(channels.map((c) => c.name), ['Zulu', 'Alpha']);
  });

  test('alphabetical mode uses natural, case-insensitive channel names', () {
    final channels = [
      _channel(1, 'Channel 10', providerOrder: 0),
      _channel(2, 'channel 2', providerOrder: 1),
      _channel(3, 'Channel 1', providerOrder: 2),
    ];

    expect(
      sortChannels(channels, ChannelSortMode.alphabetical).map((c) => c.name),
      ['Channel 1', 'channel 2', 'Channel 10'],
    );
  });

  test('numeric mode sorts valid numbers first and names afterward', () {
    final channels = [
      _channel(1, 'Ten', providerOrder: 0, channelNumber: '10'),
      _channel(2, 'Two', providerOrder: 1, channelNumber: '2'),
      _channel(3, 'No number B', providerOrder: 2),
      _channel(4, 'No number A', providerOrder: 3, channelNumber: 'HD'),
    ];

    expect(sortChannels(channels, ChannelSortMode.numeric).map((c) => c.name), [
      'Two',
      'Ten',
      'No number A',
      'No number B',
    ]);
  });

  test('numeric ties are deterministic by number text, name and id', () {
    final channels = [
      _channel(4, 'Beta', providerOrder: 4, channelNumber: '2.0'),
      _channel(3, 'Alpha', providerOrder: 3, channelNumber: '2'),
    ];

    expect(sortChannels(channels, ChannelSortMode.numeric).map((c) => c.name), [
      'Alpha',
      'Beta',
    ]);
  });
}
