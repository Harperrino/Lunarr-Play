import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';

void main() {
  group('XtreamParser VOD & Series', () {
    const host = 'http://iptv.example.com';
    const username = 'user';
    const password = 'pass';

    test('parseVodStreams maps movies with container_extension', () {
      final channels = XtreamParser.parseVodStreams(
        streamsJsonStr: jsonEncode([
          {
            'stream_id': '501',
            'name': 'Inception',
            'stream_icon': 'http://logo/inception.jpg',
            'category_id': '10',
            'container_extension': 'mkv',
          },
        ]),
        categoriesJsonStr: jsonEncode([
          {'category_id': '10', 'category_name': 'Action Movies'},
        ]),
        host: host,
        username: username,
        password: password,
      );

      expect(channels.length, 1);
      expect(channels.first.name, 'Inception');
      expect(channels.first.channelType, 'vod');
      expect(channels.first.streamId, '501');
      expect(channels.first.groupName, 'Action Movies');
      expect(
        channels.first.streamUrl,
        '$host/movie/$username/$password/501.mkv',
      );
    });

    test('parseVodStreams defaults container_extension to mp4', () {
      final channels = XtreamParser.parseVodStreams(
        streamsJsonStr: jsonEncode([
          {'stream_id': '502', 'name': 'No Ext Movie', 'category_id': '10'},
        ]),
        categoriesJsonStr: '[]',
        host: host,
        username: username,
        password: password,
      );

      expect(channels.single.streamUrl, endsWith('/502.mp4'));
    });

    test('parseSeries maps catalogue rows with cover art', () {
      final channels = XtreamParser.parseSeries(
        seriesJsonStr: jsonEncode([
          {
            'series_id': '9001',
            'name': 'Breaking Bad',
            'cover': 'http://logo/bb.jpg',
            'category_id': '20',
          },
        ]),
        categoriesJsonStr: jsonEncode([
          {'category_id': '20', 'category_name': 'Drama Series'},
        ]),
        host: host,
        username: username,
        password: password,
      );

      expect(channels.length, 1);
      expect(channels.first.name, 'Breaking Bad');
      expect(channels.first.channelType, 'series');
      expect(channels.first.streamId, '9001');
      expect(channels.first.tvgLogo, 'http://logo/bb.jpg');
      expect(channels.first.groupName, 'Drama Series');
      expect(
        channels.first.streamUrl,
        contains('/series/$username/$password/9001'),
      );
    });

    test('parseFullCatalogue merges live, vod, and series', () {
      final all = XtreamParser.parseFullCatalogue(
        XtreamCataloguePayload(
          liveStreamsJson: jsonEncode([
            {'stream_id': '1', 'name': 'News Live', 'category_id': '1'},
          ]),
          liveCategoriesJson: jsonEncode([
            {'category_id': '1', 'category_name': 'News'},
          ]),
          vodStreamsJson: jsonEncode([
            {'stream_id': '2', 'name': 'Movie One', 'category_id': '2'},
          ]),
          vodCategoriesJson: jsonEncode([
            {'category_id': '2', 'category_name': 'Movies'},
          ]),
          seriesJson: jsonEncode([
            {'series_id': '3', 'name': 'Show One', 'category_id': '3'},
          ]),
          seriesCategoriesJson: jsonEncode([
            {'category_id': '3', 'category_name': 'Shows'},
          ]),
          host: host,
          username: username,
          password: password,
        ),
      );

      expect(all.length, 3);
      expect(all.where((c) => c.channelType == 'live').length, 1);
      expect(all.where((c) => c.channelType == 'vod').length, 1);
      expect(all.where((c) => c.channelType == 'series').length, 1);
    });

    test('parseSeriesInfo extracts episodes with play URLs', () {
      final episodes = XtreamParser.parseSeriesInfo(
        seriesInfoJsonStr: jsonEncode({
          'episodes': {
            '1': [
              {
                'id': '10001',
                'title': 'Pilot',
                'episode_num': '1',
                'container_extension': 'mp4',
                'duration': '3600',
              },
              {
                'id': '10002',
                'title': 'Episode 2',
                'episode_num': '2',
                'container_extension': 'mp4',
              },
            ],
            '2': [
              {
                'id': '20001',
                'title': 'Season 2 Premiere',
                'episode_num': '1',
                'container_extension': 'mkv',
              },
            ],
          },
        }),
        host: host,
        username: username,
        password: password,
      );

      expect(episodes.length, 3);
      expect(episodes.first.title, 'Pilot');
      expect(episodes.first.season, 1);
      expect(episodes.first.episodeNum, 1);
      expect(episodes.first.durationSecs, 3600);
      expect(
        episodes.first.streamUrl,
        '$host/series/$username/$password/10001.mp4',
      );
      expect(episodes.last.season, 2);
      expect(episodes.last.streamUrl, endsWith('/20001.mkv'));
    });

    test('empty catalogue JSON returns empty lists without error', () {
      expect(
        XtreamParser.parseVodStreams(
          streamsJsonStr: '[]',
          categoriesJsonStr: '[]',
          host: host,
          username: username,
          password: password,
        ),
        isEmpty,
      );
      expect(
        XtreamParser.parseSeries(
          seriesJsonStr: '',
          categoriesJsonStr: '',
          host: host,
          username: username,
          password: password,
        ),
        isEmpty,
      );
    });
  });
}
