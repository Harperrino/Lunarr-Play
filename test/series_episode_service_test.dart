import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/series_episode_service.dart';

Channel _channel({required String streamUrl}) {
  return Channel(
    id: 1,
    playlistId: 1,
    streamId: '9001',
    name: 'Test Series',
    logo: null,
    groupName: 'Drama',
    tvgId: null,
    streamUrl: streamUrl,
    isFavorite: false,
    isWatchLater: false,
    channelType: 'series',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}

void main() {
  group('SeriesEpisodeService.isDirectPlaySeries', () {
    test('detects direct media file extensions', () {
      expect(
        SeriesEpisodeService.isDirectPlaySeries(
          _channel(streamUrl: 'http://host/show.mp4'),
        ),
        isTrue,
      );
      expect(
        SeriesEpisodeService.isDirectPlaySeries(
          _channel(streamUrl: 'http://host/show.m3u8'),
        ),
        isTrue,
      );
    });

    test('detects Xtream catalogue placeholder URLs', () {
      expect(
        SeriesEpisodeService.isDirectPlaySeries(
          _channel(streamUrl: 'http://host/series/user/pass/9001'),
        ),
        isFalse,
      );
    });

    test('returns false for empty stream URL', () {
      expect(
        SeriesEpisodeService.isDirectPlaySeries(_channel(streamUrl: '')),
        isFalse,
      );
    });
  });
}
