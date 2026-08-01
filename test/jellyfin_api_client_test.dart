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
  group('fetchPublicServerInfo', () {
    test('returns server info from a normalized base URL', () async {
      final client = _client((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://server:8096/System/Info/Public',
        );
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

    test('classifies unparsable or incomplete payloads as not Jellyfin', () async {
      for (final body in ['<html>not json</html>', '{}', '{"Version":"1"}']) {
        final client = _client(
          (request) async => http.Response(body, 200),
        );
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
    });

    test('classifies connection refused by socket error code', () async {
      final client = _client(
        (_) async =>
            throw SocketException('refused', osError: OSError('refused', 10061)),
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
        (_) async => throw SocketException(
          'lookup',
          osError: OSError('lookup', 11001),
        ),
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
        (_) async => throw SocketException(
          "Failed host lookup: 'nope.example'",
        ),
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
    test('sends credentials body and device headers, returns the session', () async {
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
    });

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
}
