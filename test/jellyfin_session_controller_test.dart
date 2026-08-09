import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';

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

class _MemoryStore extends JellyfinCredentialsStore {
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

ProviderContainer _container({
  required MockClientHandler handler,
  required JellyfinCredentialsStore store,
}) {
  return ProviderContainer(
    overrides: [
      jellyfinApiClientProvider.overrideWithValue(
        JellyfinApiClient(transport: MockClient(handler)),
      ),
      jellyfinCredentialsStoreProvider.overrideWithValue(store),
    ],
  );
}

void main() {
  test('checkServer transitions to verified and back on failure', () async {
    var failFirst = true;
    final container = _container(
      handler: (request) async {
        if (failFirst) return http.Response('nope', 404);
        return http.Response(jsonEncode(_publicInfoJson), 200);
      },
      store: _MemoryStore(),
    );
    addTearDown(container.dispose);

    final controller = container.read(
      jellyfinSessionControllerProvider.notifier,
    );

    await controller.checkServer('server:8096');
    final failureState = container.read(jellyfinSessionControllerProvider);
    expect(failureState, isA<JellyfinSessionFailure>());
    final failure = failureState as JellyfinSessionFailure;
    expect(failure.kind, JellyfinFailureKind.notJellyfin);
    expect(failure.server, isNull);

    failFirst = false;
    await controller.checkServer('server:8096');
    final verifiedState = container.read(jellyfinSessionControllerProvider);
    expect(verifiedState, isA<JellyfinServerVerified>());
    expect(
      (verifiedState as JellyfinServerVerified).server.baseUrl,
      'http://server:8096',
    );
  });

  test('signIn stores the token and authenticates the session', () async {
    final store = _MemoryStore();
    final container = _container(
      handler: (request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          return http.Response(jsonEncode(_authResponseJson), 200);
        }
        return http.Response(jsonEncode(_publicInfoJson), 200);
      },
      store: store,
    );
    addTearDown(container.dispose);

    final controller = container.read(
      jellyfinSessionControllerProvider.notifier,
    );

    await controller.checkServer('http://server:8096');
    await controller.signIn(username: 'alice', password: 'secret-pw');

    final state = container.read(jellyfinSessionControllerProvider);
    expect(state, isA<JellyfinAuthenticated>());
    final connection = (state as JellyfinAuthenticated).connection;
    expect(connection.accessToken, 'token-abc-123');
    expect(connection.username, 'alice');
    expect(store.stored?.accessToken, 'token-abc-123');
  });

  test('wrong password surfaces a 401 invalid-credentials state', () async {
    final container = _container(
      handler: (request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          return http.Response('unauthorized', 401);
        }
        return http.Response(jsonEncode(_publicInfoJson), 200);
      },
      store: _MemoryStore(),
    );
    addTearDown(container.dispose);

    final controller = container.read(
      jellyfinSessionControllerProvider.notifier,
    );

    await controller.checkServer('http://server:8096');
    await controller.signIn(username: 'alice', password: 'wrong');

    final state = container.read(jellyfinSessionControllerProvider);
    expect(state, isA<JellyfinSessionFailure>());
    final failure = state as JellyfinSessionFailure;
    expect(failure.kind, JellyfinFailureKind.invalidCredentials);
    expect(failure.statusCode, 401);
    expect(failure.server, isNotNull);
  });

  test('signOut clears the session and the credential store', () async {
    final store = _MemoryStore();
    final container = _container(
      handler: (request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          return http.Response(jsonEncode(_authResponseJson), 200);
        }
        if (request.url.path == '/Sessions/Logout') {
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(_publicInfoJson), 200);
      },
      store: store,
    );
    addTearDown(container.dispose);

    final controller = container.read(
      jellyfinSessionControllerProvider.notifier,
    );

    await controller.checkServer('http://server:8096');
    await controller.signIn(username: 'alice', password: 'secret-pw');
    expect(store.stored, isNotNull);

    await controller.signOut();

    expect(
      container.read(jellyfinSessionControllerProvider),
      isA<JellyfinIdle>(),
    );
    expect(store.stored, isNull);
  });
}
