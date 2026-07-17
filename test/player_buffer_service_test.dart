import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';

void main() {
  test('audio compatibility maps to stereo when forced', () {
    expect(
      PlayerBufferService.audioCompatibilityProperties(forceStereo: true),
      {'audio-channels': 'stereo', 'ad-lavc-downmix': 'yes'},
    );
  });

  test('audio compatibility maps to default channels when disabled', () {
    expect(
      PlayerBufferService.audioCompatibilityProperties(forceStereo: false),
      {'audio-channels': 'auto-safe', 'ad-lavc-downmix': 'no'},
    );
  });

  test('forces MPEG-TS demuxer only for continuous and ts deliveries', () {
    expect(
      PlayerBufferService.shouldForceMpegTsDemuxer(
        LiveStreamDelivery.continuous,
      ),
      isTrue,
    );
    expect(
      PlayerBufferService.shouldForceMpegTsDemuxer(
        LiveStreamDelivery.tsSegment,
      ),
      isTrue,
    );
    expect(
      PlayerBufferService.shouldForceMpegTsDemuxer(LiveStreamDelivery.hls),
      isFalse,
    );

    expect(
      PlayerBufferService.demuxerLavfFormatForDelivery(
        LiveStreamDelivery.continuous,
      ),
      'mpegts',
    );
    expect(
      PlayerBufferService.demuxerLavfFormatForDelivery(
        LiveStreamDelivery.tsSegment,
      ),
      'mpegts',
    );
    expect(
      PlayerBufferService.demuxerLavfFormatForDelivery(LiveStreamDelivery.hls),
      'hls',
    );
  });

  test(
    'live demuxer properties keep the normal MPEG-TS profile and allow recovery overrides',
    () {
      expect(
        PlayerBufferService.liveDemuxerProperties(
          delivery: LiveStreamDelivery.continuous,
        ),
        {
          'demuxer-lavf-analyzeduration': '5',
          'demuxer-lavf-probesize': '5000000',
          'demuxer-lavf-format': 'mpegts',
          'demuxer-lavf-o': 'merge_pmt_versions=1',
        },
      );

      expect(
        PlayerBufferService.liveDemuxerProperties(
          delivery: LiveStreamDelivery.continuous,
          analyzeDurationSeconds:
              PlayerBufferService.liveRecoveryAnalyzeDurationSeconds,
          probeSizeBytes: PlayerBufferService.liveRecoveryProbeSizeBytes,
          demuxerLavfFormatOverride: '',
        ),
        {
          'demuxer-lavf-analyzeduration': '10',
          'demuxer-lavf-probesize': '10000000',
          'demuxer-lavf-format': '',
          'demuxer-lavf-o': 'merge_pmt_versions=1',
        },
      );
    },
  );

  test(
    'profile reset clears forced decoder and gates unsafe playlists per mode',
    () {
      expect(PlayerBufferService.playbackProfileResetProperties(isLive: true), {
        'ad': '',
        'load-unsafe-playlists': 'yes',
      });

      expect(
        PlayerBufferService.playbackProfileResetProperties(isLive: false),
        {'ad': '', 'load-unsafe-playlists': 'no'},
      );
    },
  );

  test('vod demuxer reset clears live lavf settings for the shared player', () {
    expect(PlayerBufferService.vodDemuxerResetProperties(), {
      'demuxer-lavf-format': '',
      'demuxer-lavf-o': '',
    });
  });

  test('live track wait timeout covers analyzeduration plus headroom', () {
    expect(
      liveTrackWaitTimeoutForAnalyzeSeconds(
        PlayerBufferService.liveAnalyzeDurationSeconds,
      ),
      const Duration(seconds: 8),
    );
    expect(
      liveTrackWaitTimeoutForAnalyzeSeconds(
        PlayerBufferService.liveRecoveryAnalyzeDurationSeconds,
      ),
      const Duration(seconds: 13),
    );
  });

  test('byte cache supports the full 120 s startup buffer range', () {
    expect(PlayerBufferService.bufferSizeBytesForSeconds(3), 32 * 1024 * 1024);
    expect(
      PlayerBufferService.bufferSizeBytesForSeconds(60),
      120 * 1024 * 1024,
    );
    expect(
      PlayerBufferService.bufferSizeBytesForSeconds(120),
      240 * 1024 * 1024,
    );
  });

  test('technical read-ahead supports up to 120 s', () {
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(0), 3);
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(120), 120);
  });
}
