import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_device_profile.dart';

import 'jellyfin_test_helpers.dart';

void main() {
  group('JellyfinApiClient.fetchPlaybackInfo', () {
    test('posts direct-play-only settings and parses the response', () async {
      Map<String, dynamic>? body;
      final client = JellyfinApiClient(
        transport: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/Items/movie-1/PlaybackInfo');
          expect(request.headers['X-Emby-Token'], 'token-abc-123');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'MediaSources': [
                {
                  'Id': 'ms-1',
                  'Container': 'mkv',
                  'SupportsDirectPlay': true,
                  'SupportsDirectStream': false,
                  'SupportsTranscoding': false,
                },
              ],
              'PlaySessionId': 'ps-1',
            }),
            200,
          );
        }),
      );

      final info = await client.fetchPlaybackInfo(
        jellyfinTestConnection,
        itemId: 'movie-1',
        startTimeTicks: 500000000,
      );

      expect(info.mediaSources, hasLength(1));
      expect(info.mediaSources.first.id, 'ms-1');
      expect(info.mediaSources.first.container, 'mkv');
      expect(info.mediaSources.first.supportsDirectPlay, isTrue);
      expect(info.playSessionId, 'ps-1');

      expect(body!['EnableDirectPlay'], isTrue);
      expect(body!['EnableDirectStream'], isFalse);
      expect(body!['EnableTranscoding'], isFalse);
      expect(body!['AutoOpenLiveStream'], isFalse);
      expect(body!['StartTimeTicks'], 500000000);
      expect(body!['UserId'], 'user-id-1');
      expect(body!.containsKey('AudioStreamIndex'), isFalse);
      expect(body!.containsKey('SubtitleStreamIndex'), isFalse);

      final profile = body!['DeviceProfile'] as Map<String, dynamic>;
      expect(profile['MaxStaticBitrate'], isA<int>());
      final direct = (profile['DirectPlayProfiles'] as List).first
          as Map<String, dynamic>;
      expect(direct['Container'], contains('mkv'));
      expect(direct['VideoCodec'], contains('hevc'));
      expect(direct['AudioCodec'], contains('ac3'));
    });

    test('includes audio and subtitle indices when provided', () async {
      Map<String, dynamic>? body;
      final client = JellyfinApiClient(
        transport: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'MediaSources': <Object>[]}),
            200,
          );
        }),
      );

      await client.fetchPlaybackInfo(
        jellyfinTestConnection,
        itemId: 'movie-1',
        audioStreamIndex: 2,
        subtitleStreamIndex: 3,
      );

      expect(body!['AudioStreamIndex'], 2);
      expect(body!['SubtitleStreamIndex'], 3);
    });

    test('classifies a failing request as an unknown failure', () async {
      final client = JellyfinApiClient(
        transport: MockClient((request) async => http.Response('nope', 500)),
      );

      await expectLater(
        client.fetchPlaybackInfo(jellyfinTestConnection, itemId: 'movie-1'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.unknown,
          ),
        ),
      );
    });

    test('device profile serializes supported codecs', () {
      const profile = JellyfinDeviceProfile();
      final json = profile.toJson();

      expect(json['MaxStaticBitrate'], 120000000);
      final direct = (json['DirectPlayProfiles'] as List).single
          as Map<String, dynamic>;
      expect(direct['Container'], 'mp4,mkv,m4v,mov,webm,ts');
      expect(direct['VideoCodec'], contains('h264,hevc'));
      expect(direct['AudioCodec'], contains('aac,ac3,eac3'));
    });
  });
}
