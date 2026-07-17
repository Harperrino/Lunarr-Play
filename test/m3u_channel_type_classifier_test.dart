import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/m3u_channel_type_classifier.dart';

void main() {
  group('M3uChannelTypeClassifier', () {
    test('classifies direct video files as VOD by default', () {
      expect(
        M3uChannelTypeClassifier.classify(
          url: 'https://cdn.example.test/movie/avatar.mp4',
          name: 'Avatar 2',
          groupName: 'Movies',
        ),
        'vod',
      );
    });

    test('classifies S02E03 style direct video files as series', () {
      expect(
        M3uChannelTypeClassifier.classify(
          url: 'https://cdn.example.test/show/episode.mkv',
          name: 'Example Show S02E03',
          groupName: 'Drama',
        ),
        'series',
      );
    });

    test('does not classify ordinary words containing s1 as series', () {
      expect(
        M3uChannelTypeClassifier.classify(
          url: 'https://cdn.example.test/movie/classic.mp4',
          name: 'Classic Movie',
          groupName: 'Cinema',
        ),
        'vod',
      );
    });

    test('keeps transport streams and HLS as live by default', () {
      expect(
        M3uChannelTypeClassifier.classify(
          url: 'https://live.example.test/channel.m3u8',
          name: 'News Live',
          groupName: 'News',
        ),
        'live',
      );
    });
  });
}
