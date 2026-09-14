import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';

void main() {
  test('M3U stores file order and the supported channel-number aliases', () {
    final channels = M3uParser.parse('''
#EXTM3U
#EXTINF:-1 tvg-chno="7" group-title="News",Seven
https://example.invalid/7
#EXTINF:-1 channel-number="2" group-title="News",Two
https://example.invalid/2
#EXTINF:-1 ch-number="10" group-title="News",Ten
https://example.invalid/10
''');

    expect(channels.map((channel) => channel.providerOrder), [0, 1, 2]);
    expect(channels.map((channel) => channel.channelNumber), ['7', '2', '10']);
  });

  test('Xtream stores array index and num without changing stream parsing', () {
    final channels = XtreamParser.parseLiveStreams(
      streamsJsonStr: jsonEncode([
        {'stream_id': 'one', 'name': 'One', 'num': 101},
        {'name': 'Skipped without id', 'num': 102},
        {'stream_id': 'three', 'name': 'Three', 'num': '3'},
      ]),
      categoriesJsonStr: '[]',
      host: 'https://example.invalid',
      username: 'user',
      password: 'pass',
    );

    expect(channels.map((channel) => channel.providerOrder), [0, 2]);
    expect(channels.map((channel) => channel.channelNumber), ['101', '3']);
    expect(channels.map((channel) => channel.streamId), ['one', 'three']);
  });
}
