import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_auth_repository.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_server_info.dart';

const _publicInfoJson = {
  'ServerName': 'Media Server',
  'Version': '10.10.3',
  'Id': 'server-id-1',
};

const _authResponseJson = {
  'User': {'Name': 'alice', 'Id': 'user-id-1'},
  'AccessToken': 'token-abc-123',
  'ServerId': 'server-id-1',
};

class _RecordingStore implements JellyfinCredentialsStore {
  JellyfinConnection? stored;

  @override
  Future<void> clear() async {
    stored = null;
  }

  @override
  Future<JellyfinConnection?> read() async => stored;

  @override
  Future<void> write(JellyfinConnection connection) async {
    stored = connection;
  }
}

void main() {
  group('JellyfinAuthRepository', () {
    test('validateServer normalizes and returns server info', () async {
      final repository = JellyfinAuthRepository(
        apiClient: JellyfinApiClient(
          transport: MockClient((request) async {
            expect(
              request.url.toString(),
              'http://server:8096/System/Info/Public',
            );
            return http.Response(jsonEncode(_publicInfoJson), 200);
          }),
        ),
        credentialsStore: _RecordingStore(),
      );

      final server = await repository.validateServer(' server:8096/ ');

      expect(server.baseUrl, 'http://server:8096');
      expect(server.serverName, 'Media Server');
    });

    test('login stores the session and reuses one device id', () async {
      final store = _RecordingStore();
      final deviceIds = <String>[];
      final repository = JellyfinAuthRepository(
        apiClient: JellyfinApiClient(
          transport: MockClient((request) async {
            if (request.url.path == '/Users/AuthenticateByName') {
              deviceIds.add(
                request.headers['X-Emby-Authorization']!
                    .split('DeviceId="')[1]
                    .split('"')[0],
              );
              return http.Response(jsonEncode(_authResponseJson), 200);
            }
            return http.Response('not found', 404);
          }),
        ),
        credentialsStore: store,
      );

      final server = JellyfinServerInfo(
        baseUrl: 'http://server:8096',
        serverName: 'Media Server',
        serverVersion: '10.10.3',
        serverId: 'server-id-1',
      );
      final connection = await repository.login(
        server: server,
        username: 'alice',
        password: 'secret-pw',
      );

      expect(connection.accessToken, 'token-abc-123');
      expect(connection.userId, 'user-id-1');
      expect(connection.username, 'alice');
      expect(connection.serverId, 'server-id-1');
      expect(connection.serverVersion, '10.10.3');
      expect(connection.deviceId, isNotEmpty);
      expect(store.stored?.accessToken, 'token-abc-123');
      expect(store.stored?.deviceId, connection.deviceId);
      expect(deviceIds, [connection.deviceId]);

      final second = await repository.login(
        server: server,
        username: 'alice',
        password: 'secret-pw',
      );
      expect(second.deviceId, connection.deviceId);
    });

    test('logout clears the store even when the server call fails', () async {
      final store = _RecordingStore()..stored = const JellyfinConnection(
        baseUrl: 'http://server:8096',
        serverId: 'server-id-1',
        serverVersion: '10.10.3',
        userId: 'user-id-1',
        username: 'alice',
        accessToken: 'token-abc-123',
        deviceId: 'device-42',
      );
      final repository = JellyfinAuthRepository(
        apiClient: JellyfinApiClient(
          transport: MockClient((request) async => throw Exception('offline')),
        ),
        credentialsStore: store,
      );

      final connection = store.stored!;
      await repository.logout(connection);

      expect(store.stored, isNull);
    });

    test('the in-memory store never persists and clears on demand', () async {
      final store = InMemoryJellyfinCredentialsStore();
      const connection = JellyfinConnection(
        baseUrl: 'http://server:8096',
        serverId: 'server-id-1',
        serverVersion: '10.10.3',
        userId: 'user-id-1',
        username: 'alice',
        accessToken: 'token-abc-123',
        deviceId: 'device-42',
      );

      expect(await store.read(), isNull);
      await store.write(connection);
      expect((await store.read())?.accessToken, 'token-abc-123');
      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
