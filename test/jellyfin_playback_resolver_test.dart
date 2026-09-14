import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_info.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';

const _item = JellyfinItem(
  id: 'movie-1',
  name: 'Test Movie',
  type: 'Movie',
  playbackPositionTicks: 900000000,
);

void main() {
  const resolver = JellyfinPlaybackResolver();

  test('resolves a direct-play source into a static stream URL', () {
    final resolved = resolver.resolve(
      baseUrl: 'http://server:8096',
      accessToken: 'token-abc-123',
      item: _item,
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(
            id: 'ms-1',
            container: 'mp4',
            supportsDirectPlay: true,
          ),
        ],
        playSessionId: 'ps-1',
      ),
    );

    final uri = Uri.parse(resolved.uri);
    expect(uri.path, '/Videos/movie-1/stream');
    expect(uri.queryParameters['static'], 'true');
    expect(uri.queryParameters['MediaSourceId'], 'ms-1');
    expect(uri.queryParameters['api_key'], 'token-abc-123');
    expect(resolved.headers, {'X-Emby-Token': 'token-abc-123'});
    expect(resolved.mediaSourceId, 'ms-1');
    expect(resolved.playSessionId, 'ps-1');
    expect(resolved.method, JellyfinPlaybackMethod.directPlay);
    // 900000000 ticks * 100 ns = 90 s.
    expect(resolved.startPosition, const Duration(seconds: 90));
  });

  test('starts at zero when no resume position exists', () {
    final resolved = resolver.resolve(
      baseUrl: 'http://server:8096',
      accessToken: 'token',
      item: const JellyfinItem(id: 'm2', name: 'Fresh', type: 'Movie'),
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(id: 'ms-2', supportsDirectPlay: true),
        ],
      ),
    );

    expect(resolved.startPosition, Duration.zero);
  });

  test('skips non-direct sources and picks the first direct one', () {
    final resolved = resolver.resolve(
      baseUrl: 'http://server:8096',
      accessToken: 'token',
      item: _item,
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(id: 'ms-transcode', supportsTranscoding: true),
          JellyfinMediaSource(
            id: 'ms-direct',
            container: 'mkv',
            supportsDirectPlay: true,
          ),
        ],
      ),
    );

    expect(resolved.mediaSourceId, 'ms-direct');
    expect(resolved.uri, contains('MediaSourceId=ms-direct'));
    expect(Uri.parse(resolved.uri).queryParameters['static'], 'true');
  });

  test('falls back to direct stream when direct play is unavailable', () {
    final resolved = resolver.resolve(
      baseUrl: 'http://server:8096',
      accessToken: 'token',
      item: _item,
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(
            id: 'ms-remux',
            container: 'ts',
            supportsDirectStream: true,
            transcodingUrl:
                '/Videos/movie-1/master.m3u8?Existing=value%20with%20spaces',
          ),
          JellyfinMediaSource(
            id: 'ms-transcode',
            supportsTranscoding: true,
            transcodingUrl:
                '/Videos/movie-1/master.m3u8?MediaSourceId=ms-transcode',
          ),
        ],
      ),
      audioStreamIndex: 2,
      subtitleStreamIndex: -1,
    );

    expect(resolved.method, JellyfinPlaybackMethod.directStream);
    expect(resolved.mediaSourceId, 'ms-remux');
    final uri = Uri.parse(resolved.uri);
    expect(uri.queryParameters['static'], isNull);
    expect(uri.queryParameters['Existing'], 'value with spaces');
    expect(uri.queryParameters['MediaSourceId'], 'ms-remux');
    expect(uri.queryParameters['AudioStreamIndex'], '2');
    expect(uri.queryParameters['SubtitleStreamIndex'], '-1');
    expect(uri.queryParameters['api_key'], 'token');
  });

  test('uses Jellyfin TranscodingUrl for a transcode decision', () {
    final resolved = resolver.resolve(
      baseUrl: 'http://server:8096',
      accessToken: 'token',
      item: _item,
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(
            id: 'ms-transcode',
            supportsTranscoding: true,
            transcodingUrl:
                '/Videos/movie-1/master.m3u8?MediaSourceId=ms-transcode',
          ),
        ],
      ),
      startTimeTicks: 1200000000,
    );

    expect(resolved.method, JellyfinPlaybackMethod.transcode);
    final uri = Uri.parse(resolved.uri);
    expect(uri.path, '/Videos/movie-1/master.m3u8');
    expect(uri.queryParameters['MediaSourceId'], 'ms-transcode');
    expect(uri.queryParameters['api_key'], 'token');
    expect(resolved.startPosition, const Duration(seconds: 120));
  });

  test('throws when no direct-play source is available', () {
    expect(
      () => resolver.resolve(
        baseUrl: 'http://server:8096',
        accessToken: 'token',
        item: _item,
        playbackInfo: const JellyfinPlaybackInfo(
          mediaSources: [
            JellyfinMediaSource(id: 'ms-transcode', supportsTranscoding: true),
          ],
        ),
      ),
      throwsA(isA<JellyfinPlaybackResolutionException>()),
    );
  });

  test('skips a direct-stream source without a server URL', () {
    final resolved = resolver.resolve(
      baseUrl: 'http://server:8096',
      accessToken: 'token',
      item: _item,
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(id: 'ms-missing-url', supportsDirectStream: true),
          JellyfinMediaSource(
            id: 'ms-transcode',
            supportsTranscoding: true,
            transcodingUrl: '/Videos/movie-1/master.m3u8',
          ),
        ],
      ),
    );

    expect(resolved.method, JellyfinPlaybackMethod.transcode);
    expect(resolved.mediaSourceId, 'ms-transcode');
  });

  test(
    'rejects a playback URL on another origin without exposing the token',
    () {
      expect(
        () => resolver.resolve(
          baseUrl: 'https://server:8096',
          accessToken: 'secret-token',
          item: _item,
          playbackInfo: const JellyfinPlaybackInfo(
            mediaSources: [
              JellyfinMediaSource(
                id: 'ms-external',
                supportsTranscoding: true,
                transcodingUrl: 'https://evil.example/stream.m3u8',
              ),
            ],
          ),
        ),
        throwsA(
          isA<JellyfinPlaybackResolutionException>()
              .having((error) => error.message, 'message', contains('outside'))
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret-token')),
              ),
        ),
      );
    },
  );

  test('rejects an HTTPS-to-HTTP playback downgrade', () {
    expect(
      () => resolver.resolve(
        baseUrl: 'https://server:8096',
        accessToken: 'token',
        item: _item,
        playbackInfo: const JellyfinPlaybackInfo(
          mediaSources: [
            JellyfinMediaSource(
              id: 'ms-downgrade',
              supportsTranscoding: true,
              transcodingUrl: 'http://server:8096/stream.m3u8',
            ),
          ],
        ),
      ),
      throwsA(isA<JellyfinPlaybackResolutionException>()),
    );
  });

  test('replaces server auth parameters and encodes the current token', () {
    final resolved = resolver.resolve(
      baseUrl: 'https://server',
      accessToken: 'token with & symbols',
      item: _item,
      playbackInfo: const JellyfinPlaybackInfo(
        mediaSources: [
          JellyfinMediaSource(
            id: 'ms-transcode',
            supportsTranscoding: true,
            transcodingUrl:
                'https://server/Videos/movie-1/master.m3u8'
                '?api_key=old-token&MediaSourceId=old&Foo=bar',
          ),
        ],
      ),
    );

    final uri = Uri.parse(resolved.uri);
    expect(uri.queryParameters['api_key'], 'token with & symbols');
    expect(uri.queryParameters['MediaSourceId'], 'ms-transcode');
    expect(uri.queryParameters['Foo'], 'bar');
    expect(resolved.uri, isNot(contains('old-token')));
    expect(resolved.uri, isNot(contains('token with & symbols')));
  });

  test('playback info parsing ignores unknown fields', () {
    final info = JellyfinPlaybackInfo.fromJson({
      'MediaSources': [
        {
          'Id': 'ms-1',
          'SupportsDirectPlay': true,
          'DefaultAudioStreamIndex': 1,
          'MediaStreams': [
            {'Index': 0, 'Type': 1, 'Codec': 'h264', 'IsDefault': true},
            {
              'Index': 1,
              'Type': 0,
              'Codec': 'eac3',
              'Language': 'deu',
              'Channels': 6,
              'ChannelLayout': '5.1',
              'DisplayTitle': 'Deutsch - EAC3 - 5.1',
            },
          ],
          'FutureField': 1,
        },
        {'Id': 'ms-2'},
      ],
      'PlaySessionId': 'ps-9',
      'Extra': true,
    });

    expect(info.mediaSources, hasLength(2));
    expect(info.mediaSources.first.supportsDirectPlay, isTrue);
    expect(info.mediaSources.first.container, '');
    expect(info.mediaStreams, hasLength(2));
    expect(info.mediaStreams[1].type, JellyfinMediaStreamType.audio);
    expect(info.mediaStreams[1].language, 'deu');
    expect(info.mediaStreams[1].channels, 6);
    expect(info.defaultAudioStreamIndex, 1);
    expect(info.mediaSources[1].supportsDirectPlay, isFalse);
    expect(info.playSessionId, 'ps-9');
  });
}
