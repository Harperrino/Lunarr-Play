import 'dart:async';
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

class _DeferredReadStore extends _MemoryStore {
  final Completer<JellyfinConnection?> restored = Completer();

  @override
  Future<JellyfinConnection?> read() => restored.future;
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

  test('serializes sign-in and sign-out in invocation order', () async {
    final authentication = Completer<http.Response>();
    final store = _MemoryStore();
    final container = _container(
      handler: (request) async {
        if (request.url.path == '/Users/AuthenticateByName') {
          return authentication.future;
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

    final signIn = controller.signIn(username: 'alice', password: 'secret-pw');
    final signOut = controller.signOut();
    authentication.complete(http.Response(jsonEncode(_authResponseJson), 200));
    await Future.wait([signIn, signOut]);

    expect(
      container.read(jellyfinSessionControllerProvider),
      isA<JellyfinIdle>(),
    );
    expect(store.stored, isNull);
  });

  test('a queued add-account action wins over an older server check', () async {
    final validation = Completer<http.Response>();
    final container = _container(
      handler: (_) => validation.future,
      store: _MemoryStore(),
    );
    addTearDown(container.dispose);
    final controller = container.read(
      jellyfinSessionControllerProvider.notifier,
    );

    final check = controller.checkServer('http://server:8096');
    final add = controller.startAddingConnection();
    validation.complete(http.Response(jsonEncode(_publicInfoJson), 200));
    await Future.wait([check, add]);

    expect(
      container.read(jellyfinSessionControllerProvider),
      isA<JellyfinIdle>(),
    );
  });

  test(
    'a late initial restore cannot replace a newer session action',
    () async {
      final store = _DeferredReadStore();
      final container = _container(
        handler: (_) async => http.Response(jsonEncode(_publicInfoJson), 200),
        store: store,
      );
      addTearDown(container.dispose);
      final controller = container.read(
        jellyfinSessionControllerProvider.notifier,
      );

      await controller.checkServer('http://server:8096');
      store.restored.complete(
        const JellyfinConnection(
          baseUrl: 'http://old:8096',
          serverId: 'old-server',
          serverVersion: '10.10.0',
          userId: 'old-user',
          username: 'old',
          accessToken: 'old-token',
          deviceId: 'old-device',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(jellyfinSessionControllerProvider),
        isA<JellyfinServerVerified>(),
      );
    },
  );
}
