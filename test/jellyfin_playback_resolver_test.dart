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

    expect(
      resolved.uri,
      'http://server:8096/Videos/movie-1/stream'
      '?static=true&MediaSourceId=ms-1&api_key=token-abc-123',
    );
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
          JellyfinMediaSource(
            id: 'ms-transcode',
            supportsTranscoding: true,
          ),
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
    expect(resolved.uri, contains('static=true'));
  });

  test('throws when no direct-play source is available', () {
    expect(
      () => resolver.resolve(
        baseUrl: 'http://server:8096',
        accessToken: 'token',
        item: _item,
        playbackInfo: const JellyfinPlaybackInfo(
          mediaSources: [
            JellyfinMediaSource(
              id: 'ms-transcode',
              supportsTranscoding: true,
            ),
          ],
        ),
      ),
      throwsA(isA<JellyfinPlaybackResolutionException>()),
    );
  });

  test('playback info parsing ignores unknown fields', () {
    final info = JellyfinPlaybackInfo.fromJson({
      'MediaSources': [
        {'Id': 'ms-1', 'SupportsDirectPlay': true, 'FutureField': 1},
        {'Id': 'ms-2'},
      ],
      'PlaySessionId': 'ps-9',
      'Extra': true,
    });

    expect(info.mediaSources, hasLength(2));
    expect(info.mediaSources.first.supportsDirectPlay, isTrue);
    expect(info.mediaSources.first.container, '');
    expect(info.mediaSources[1].supportsDirectPlay, isFalse);
    expect(info.playSessionId, 'ps-9');
  });
}
