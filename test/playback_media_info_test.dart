import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';

void main() {
  group('vodBufferedEndMs', () {
    test('extends timeline by forward buffer from current position', () {
      expect(
        vodBufferedEndMs(
          positionMs: 600000,
          forwardBufferMs: 90000,
          durationMs: 3600000,
        ),
        690000,
      );
    });

    test('clamps to duration', () {
      expect(
        vodBufferedEndMs(
          positionMs: 3500000,
          forwardBufferMs: 120000,
          durationMs: 3600000,
        ),
        3600000,
      );
    });
  });

  group('PlaybackMediaInfo', () {
    test('resolutionLabel formats width x height', () {
      const info = PlaybackMediaInfo(videoWidth: 1920, videoHeight: 1080);
      expect(info.resolutionLabel, '1920×1080');
    });

    test('containerLabel from uri extension', () {
      const info = PlaybackMediaInfo(
        playbackUri: 'https://x.test/movie/file.mkv',
      );
      expect(info.containerLabel, 'MKV');
    });
  });
}
