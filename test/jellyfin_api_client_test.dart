import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';

const _publicInfoJson = {
  'ServerName': 'Media Server',
  'Version': '10.10.3',
  'Id': 'server-id-1',
  'OperatingSystem': 'Windows',
};

const _authResponseJson = {
  'User': {'Name': 'alice', 'Id': 'user-id-1'},
  'AccessToken': 'token-abc-123',
  'ServerId': 'server-id-1',
};

JellyfinApiClient _client(MockClientHandler handler) =>
    JellyfinApiClient(transport: MockClient(handler));

void main() {
  const connection = JellyfinConnection(
    baseUrl: 'http://server:8096',
    serverId: 'server-id-1',
    serverVersion: '10.10.3',
    userId: 'user-id-1',
    username: 'alice',
    accessToken: 'token-abc-123',
    deviceId: 'device-42',
  );

  group('fetchPublicServerInfo', () {
    test('returns server info from a normalized base URL', () async {
      final client = _client((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://server:8096/System/Info/Public');
        return http.Response(jsonEncode(_publicInfoJson), 200);
      });

      final server = await client.fetchPublicServerInfo('  server:8096///');

      expect(server.baseUrl, 'http://server:8096');
      expect(server.serverName, 'Media Server');
      expect(server.serverVersion, '10.10.3');
      expect(server.serverId, 'server-id-1');
      expect(server.operatingSystem, 'Windows');
    });

    test('classifies non-200 responses as not a Jellyfin server', () async {
      final client = _client((request) async => http.Response('nope', 404));

      await expectLater(
        client.fetchPublicServerInfo('http://server:8096'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.notJellyfin,
          ),
        ),
      );
    });

    test(
      'classifies unparsable or incomplete payloads as not Jellyfin',
      () async {
        for (final body in ['<html>not json</html>', '{}', '{"Version":"1"}']) {
          final client = _client((request) async => http.Response(body, 200));
          await expectLater(
            client.fetchPublicServerInfo('http://server:8096'),
            throwsA(
              isA<JellyfinApiException>().having(
                (e) => e.kind,
                'kind',
                JellyfinFailureKind.notJellyfin,
              ),
            ),
          );
        }
      },
    );

    test('classifies connection refused by socket error code', () async {
      final client = _client(
        (_) async => throw SocketException(
          'refused',
          osError: OSError('refused', 10061),
        ),
      );

      await expectLater(
        client.fetchPublicServerInfo('http://server:8096'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.connectionRefused,
          ),
        ),
      );
    });

    test('classifies DNS failures by socket error code and message', () async {
      final byCode = _client(
        (_) async =>
            throw SocketException('lookup', osError: OSError('lookup', 11001)),
      );
      await expectLater(
        byCode.fetchPublicServerInfo('http://nope.example'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.dns,
          ),
        ),
      );

      final byMessage = _client(
        (_) async =>
            throw SocketException("Failed host lookup: 'nope.example'"),
      );
      await expectLater(
        byMessage.fetchPublicServerInfo('http://nope.example'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.dns,
          ),
        ),
      );
    });

    test('classifies timeouts and TLS handshake failures', () async {
      final timeoutClient = _client(
        (_) async => throw TimeoutException('too slow'),
      );
      await expectLater(
        timeoutClient.fetchPublicServerInfo('http://server:8096'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.timeout,
          ),
        ),
      );

      final tlsClient = _client(
        (_) async => throw HandshakeException('certificate invalid'),
      );
      await expectLater(
        tlsClient.fetchPublicServerInfo('https://server:8920'),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.tls,
          ),
        ),
      );
    });
  });

  group('authenticateByName', () {
    test(
      'sends credentials body and device headers, returns the session',
      () async {
        final client = _client((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/Users/AuthenticateByName');
          final authorization = request.headers['X-Emby-Authorization']!;
          expect(authorization, contains('DeviceId="device-42"'));
          expect(authorization, contains('Token=""'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['Username'], 'alice');
          expect(body['Pw'], 'secret-pw');

          return http.Response(jsonEncode(_authResponseJson), 200);
        });

        final auth = await client.authenticateByName(
          baseUrl: 'http://server:8096',
          username: 'alice',
          password: 'secret-pw',
          deviceId: 'device-42',
        );

        expect(auth.accessToken, 'token-abc-123');
        expect(auth.userId, 'user-id-1');
        expect(auth.username, 'alice');
        expect(auth.serverId, 'server-id-1');
      },
    );

    test('classifies 401 as invalid credentials', () async {
      final client = _client(
        (request) async => http.Response('unauthorized', 401),
      );

      await expectLater(
        client.authenticateByName(
          baseUrl: 'http://server:8096',
          username: 'alice',
          password: 'wrong',
          deviceId: 'device-42',
        ),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.invalidCredentials,
          ),
        ),
      );
    });

    test('classifies malformed authentication responses as unknown', () async {
      final client = _client(
        (request) async => http.Response('{"AccessToken":"only-token"}', 200),
      );

      await expectLater(
        client.authenticateByName(
          baseUrl: 'http://server:8096',
          username: 'alice',
          password: 'pw',
          deviceId: 'device-42',
        ),
        throwsA(
          isA<JellyfinApiException>().having(
            (e) => e.kind,
            'kind',
            JellyfinFailureKind.unknown,
          ),
        ),
      );
    });
  });

  group('logout', () {
    test('sends the access token header', () async {
      var logoutSeen = false;
      final client = _client((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/Sessions/Logout');
        expect(request.headers['X-Emby-Token'], 'token-abc-123');
        logoutSeen = true;
        return http.Response('', 204);
      });

      final connection = JellyfinConnection(
        baseUrl: 'http://server:8096',
        serverId: 'server-id-1',
        serverVersion: '10.10.3',
        userId: 'user-id-1',
        username: 'alice',
        accessToken: 'token-abc-123',
        deviceId: 'device-42',
      );

      await client.logout(connection);
      expect(logoutSeen, isTrue);
    });
  });

  group('item status', () {
    test('uses the Jellyfin favorite and played endpoints', () async {
      final requests = <http.BaseRequest>[];
      final client = _client((request) async {
        requests.add(request);
        expect(request.headers['X-Emby-Token'], connection.accessToken);
        return http.Response('', 204);
      });

      await client.markFavorite(connection, itemId: 'item-1');
      await client.unmarkFavorite(connection, itemId: 'item-1');
      await client.markPlayed(connection, itemId: 'item-1');
      await client.markUnplayed(connection, itemId: 'item-1');

      expect(
        requests.map((request) => '${request.method} ${request.url.path}'),
        [
          'POST /Users/user-id-1/FavoriteItems/item-1',
          'DELETE /Users/user-id-1/FavoriteItems/item-1',
          'POST /Users/user-id-1/PlayedItems/item-1',
          'DELETE /Users/user-id-1/PlayedItems/item-1',
        ],
      );
    });

    test('rolls API errors up as a typed failure', () async {
      final client = _client((request) async => http.Response('failed', 503));

      await expectLater(
        client.markFavorite(connection, itemId: 'item-1'),
        throwsA(
          isA<JellyfinApiException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.kind,
                'kind',
                JellyfinFailureKind.unknown,
              ),
        ),
      );
    });
  });

  group('playback assist data', () {
    test('parses media segments and treats 404 as unavailable', () async {
      var unavailable = false;
      final client = _client((request) async {
        expect(request.headers['X-Emby-Token'], connection.accessToken);
        if (unavailable) return http.Response('', 404);
        return http.Response(
          jsonEncode({
            'Items': [
              {
                'Id': 'intro',
                'Type': 'Intro',
                'StartTicks': 0,
                'EndTicks': 100000000,
              },
            ],
          }),
          200,
        );
      });

      expect(
        await client.fetchMediaSegments(connection, itemId: 'episode'),
        hasLength(1),
      );
      unavailable = true;
      expect(
        await client.fetchMediaSegments(connection, itemId: 'episode'),
        isEmpty,
      );
    });

    test('couples trickplay metadata and tiles to the media source', () async {
      final client = _client((request) async {
        expect(request.headers['X-Emby-Token'], connection.accessToken);
        if (request.url.path.contains('/Trickplay/')) {
          expect(request.url.queryParameters['MediaSourceId'], 'source-a');
          return http.Response.bytes([1, 2, 3], 200);
        }
        return http.Response(
          jsonEncode({
            'Trickplay': {
              'source-a': {
                '320': {
                  'Width': 320,
                  'Height': 180,
                  'TileWidth': 4,
                  'TileHeight': 3,
                  'ThumbnailCount': 12,
                  'Interval': 10000,
                },
              },
              'source-b': {},
            },
          }),
          200,
        );
      });

      final manifest = await client.fetchTrickplayManifest(
        connection,
        itemId: 'episode',
        mediaSourceId: 'source-a',
      );
      expect(manifest?.mediaSourceId, 'source-a');
      expect(manifest?.bestResolution()?.width, 320);
      expect(
        await client.fetchTrickplayTile(
          connection,
          itemId: 'episode',
          mediaSourceId: 'source-a',
          width: 320,
          index: 0,
        ),
        [1, 2, 3],
      );
    });

    test('rejects oversized trickplay tiles', () async {
      final client = _client(
        (_) async => http.Response.bytes(
          List<int>.filled(JellyfinApiClient.maximumTrickplayTileBytes + 1, 0),
          200,
        ),
      );
      expect(
        await client.fetchTrickplayTile(
          connection,
          itemId: 'episode',
          mediaSourceId: 'source-a',
          width: 320,
          index: 0,
        ),
        isNull,
      );
    });
  });
}
