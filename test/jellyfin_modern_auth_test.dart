import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_auth_repository.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_authorization.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';

void main() {
  test('validate, login, browse and logout without legacy authentication', () async {
    final visited = <String>[];
    final api = JellyfinApiClient(
      transport: MockClient((request) async {
        visited.add(request.url.path);
        expect(request.headers.containsKey('X-Emby-Authorization'), isFalse);
        expect(request.headers.containsKey('X-Emby-Token'), isFalse);
        switch (request.url.path) {
          case '/jellyfin/System/Info/Public':
            return http.Response(
              jsonEncode({
                'ServerName': 'Modern server',
                'Version': '12.1',
                'Id': 'server',
              }),
              200,
            );
          case '/jellyfin/Users/AuthenticateByName':
            // v12.1 AuthorizationContext accepts MediaBrowser in Authorization
            // while EnableLegacyAuthorization defaults to false.
            final header = request.headers['Authorization'] ?? '';
            if (!header.startsWith('MediaBrowser ') ||
                !header.contains('DeviceId="')) {
              return http.Response('', 400);
            }
            return http.Response(
              jsonEncode({
                'User': {'Id': 'user', 'Name': 'Alice'},
                'AccessToken': 'synthetic-token',
                'ServerId': 'server',
              }),
              200,
            );
          default:
            final header = request.headers['Authorization'] ?? '';
            if (!header.startsWith('MediaBrowser ') ||
                !header.contains('Token="synthetic-token"')) {
              return http.Response('', 401);
            }
            return request.url.path.endsWith('/Logout')
                ? http.Response('', 204)
                : http.Response(jsonEncode({'Items': []}), 200);
        }
      }),
    );
    final store = InMemoryJellyfinCredentialsStore();
    final auth = JellyfinAuthRepository(
      apiClient: api,
      credentialsStore: store,
    );
    final server = await auth.validateServer(
      'https://example.invalid/jellyfin',
    );
    final connection = await auth.login(
      server: server,
      username: 'Alice',
      password: 'synthetic-password',
    );
    expect(await api.fetchUserViews(connection), isEmpty);
    final poster = const JellyfinImageService().posterUrl(
      connection,
      itemId: 'item',
      imageTag: 'tag',
    );
    final query = Uri.parse(poster!).queryParameters;
    expect(query['ApiKey'], 'synthetic-token');
    expect(query.containsKey('api_key'), isFalse);
    await auth.logout(connection);
    expect(await store.readActive(), isNull);
    expect(
      visited,
      containsAll([
        '/jellyfin/System/Info/Public',
        '/jellyfin/Users/AuthenticateByName',
        '/jellyfin/Users/user/Views',
        '/jellyfin/Sessions/Logout',
      ]),
    );
  });

  test('header values cannot introduce new parameters or line breaks', () {
    final header = jellyfinAuthorization(
      deviceId: 'device", Token="other',
      token: 'a"\r\n, b&+',
    );
    expect(header, isNot(contains('\r')));
    expect(header, isNot(contains('\n')));
    expect(RegExp('Token=').allMatches(header), hasLength(1));
    final value = header.split('Token="').last.split('"').first;
    expect(Uri.decodeComponent(value), 'a"\r\n, b&+');
  });
}
