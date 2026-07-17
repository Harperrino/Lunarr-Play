import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';

void main() {
  test(
    'playbackAttempts keeps app/mpv candidates first and adds fallback headers later',
    () {
      final attempts = LiveStreamUrl.playbackAttempts(
        'http://iptv.example.com/live/u/p/123',
      );

      expect(attempts.first.headerProfile, LiveStreamHeaderProfile.appMpv);
      expect(
        attempts.first.playbackUrl,
        'http://iptv.example.com/live/u/p/123',
      );
      expect(
        attempts
            .takeWhile(
              (attempt) =>
                  attempt.headerProfile == LiveStreamHeaderProfile.appMpv,
            )
            .length,
        3,
      );
      expect(
        attempts.any(
          (attempt) => attempt.headerProfile == LiveStreamHeaderProfile.vlcLike,
        ),
        isTrue,
      );
      expect(
        attempts.any(
          (attempt) =>
              attempt.headerProfile == LiveStreamHeaderProfile.browserLike,
        ),
        isTrue,
      );
    },
  );

  test('playbackAttempts keeps delivery labels aligned with URL shape', () {
    final attempts = LiveStreamUrl.playbackAttempts(
      'http://iptv.example.com/live/u/p/123',
    );
    final labels = attempts.map((attempt) => attempt.deliveryType).toSet();

    expect(labels, containsAll(['continuous', 'ts', 'hls']));
  });

  test('playbackAttempts keeps extensionless then ts fallback order', () {
    const source = 'http://iptv.example.com/live/u/p/123';
    final appMpvAttempts = LiveStreamUrl.playbackAttempts(source)
        .where(
          (attempt) => attempt.headerProfile == LiveStreamHeaderProfile.appMpv,
        )
        .map((attempt) => attempt.playbackUrl)
        .toList();

    expect(appMpvAttempts, [source, '$source.ts', '$source.m3u8']);
  });

  test('playbackAttempts exposes distinct header profiles', () {
    final attempts = LiveStreamUrl.playbackAttempts(
      'http://iptv.example.com/live/u/p/123',
    );

    expect(
      attempts
          .firstWhere(
            (attempt) =>
                attempt.headerProfile == LiveStreamHeaderProfile.appMpv,
          )
          .headers['User-Agent'],
      contains('mpv'),
    );
    expect(
      attempts
          .firstWhere(
            (attempt) =>
                attempt.headerProfile == LiveStreamHeaderProfile.vlcLike,
          )
          .headers['User-Agent'],
      contains('VLC'),
    );
    expect(
      attempts
          .firstWhere(
            (attempt) =>
                attempt.headerProfile == LiveStreamHeaderProfile.browserLike,
          )
          .headers['User-Agent'],
      contains('Chrome'),
    );
  });

  test(
    'playbackAttempts keeps a VLC-like candidate for the original source URL',
    () {
      final attempts = LiveStreamUrl.playbackAttempts(
        'http://iptv.example.com/live/u/p/123',
      );

      expect(
        attempts.any(
          (attempt) =>
              attempt.headerProfile == LiveStreamHeaderProfile.vlcLike &&
              attempt.playbackUrl == 'http://iptv.example.com/live/u/p/123',
        ),
        isTrue,
      );
    },
  );

  test('deliveryFor treats explicit probes and HLS hints as HLS', () {
    expect(
      LiveStreamUrl.deliveryFor(
        'http://iptv.example.com/live/u/p/123',
        looksLikeHls: true,
      ),
      LiveStreamDelivery.hls,
    );

    expect(
      LiveStreamUrl.deliveryFor(
        'http://iptv.example.com/live/u/p/123?output=m3u8',
      ),
      LiveStreamDelivery.hls,
    );
    expect(
      LiveStreamUrl.deliveryFor(
        'http://iptv.example.com/live/u/p/123?type=hls',
      ),
      LiveStreamDelivery.hls,
    );
  });

  test('deliveryFor keeps plain TS and M3U8 extensions stable', () {
    expect(
      LiveStreamUrl.deliveryFor('http://iptv.example.com/live/u/p/123.ts'),
      LiveStreamDelivery.tsSegment,
    );
    expect(
      LiveStreamUrl.deliveryFor('http://iptv.example.com/live/u/p/123.m3u8'),
      LiveStreamDelivery.hls,
    );
  });

  test(
    'deliveryFor ignores unrelated query substrings that merely mention hls',
    () {
      expect(
        LiveStreamUrl.deliveryFor('http://iptv.example.com/live/u/p/123?hls=0'),
        LiveStreamDelivery.continuous,
      );
      expect(
        LiveStreamUrl.deliveryFor(
          'http://iptv.example.com/live/u/p/123?token=abc_hls_xyz',
        ),
        LiveStreamDelivery.continuous,
      );
    },
  );
}
