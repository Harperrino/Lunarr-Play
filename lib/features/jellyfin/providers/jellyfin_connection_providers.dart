import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_auth_repository.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_server_info.dart';

/// Injectable API client with the default HTTP transport.
final jellyfinApiClientProvider = Provider<JellyfinApiClient>(
  (ref) => JellyfinApiClient(),
);

final jellyfinCredentialsStoreProvider = Provider<JellyfinCredentialsStore>(
  (ref) => Platform.isWindows
      ? PersistentJellyfinCredentialsStore(
          cipher: const WindowsDpapiCredentialCipher(),
        )
      : InMemoryJellyfinCredentialsStore(),
);

/// Saved accounts for the Jellyfin title-bar selector.
final jellyfinConnectionsProvider = FutureProvider<List<JellyfinConnection>>(
  (ref) => ref.watch(jellyfinCredentialsStoreProvider).readAll(),
);

final jellyfinAuthRepositoryProvider = Provider<JellyfinAuthRepository>((ref) {
  return JellyfinAuthRepository(
    apiClient: ref.watch(jellyfinApiClientProvider),
    credentialsStore: ref.watch(jellyfinCredentialsStoreProvider),
  );
});

/// Connection lifecycle of the Jellyfin feature.
sealed class JellyfinSessionState {
  const JellyfinSessionState();
}

class JellyfinIdle extends JellyfinSessionState {
  const JellyfinIdle();
}

class JellyfinRestoringSession extends JellyfinSessionState {
  const JellyfinRestoringSession();
}

class JellyfinVerifyingServer extends JellyfinSessionState {
  const JellyfinVerifyingServer({required this.inputUrl});

  final String inputUrl;
}

class JellyfinServerVerified extends JellyfinSessionState {
  const JellyfinServerVerified({required this.server});

  final JellyfinServerInfo server;
}

class JellyfinSigningIn extends JellyfinSessionState {
  const JellyfinSigningIn({required this.server});

  final JellyfinServerInfo server;
}

class JellyfinAuthenticated extends JellyfinSessionState {
  const JellyfinAuthenticated({required this.connection});

  final JellyfinConnection connection;
}

/// [server] is non-null when the server was verified but sign-in failed.
class JellyfinSessionFailure extends JellyfinSessionState {
  const JellyfinSessionFailure({
    required this.kind,
    this.statusCode,
    this.server,
  });

  final JellyfinFailureKind kind;
  final int? statusCode;
  final JellyfinServerInfo? server;
}

class JellyfinSessionController extends Notifier<JellyfinSessionState> {
  var _restoreGeneration = 0;
  Future<void> _actionTail = Future<void>.value();

  @override
  JellyfinSessionState build() {
    final restoreGeneration = ++_restoreGeneration;
    Future<void>(() async {
      try {
        final connection = await ref
            .read(jellyfinCredentialsStoreProvider)
            .readActive();
        if (restoreGeneration == _restoreGeneration && connection != null) {
          state = JellyfinAuthenticated(connection: connection);
        } else if (restoreGeneration == _restoreGeneration) {
          state = const JellyfinIdle();
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'JellyfinSessionController: Could not restore saved session.',
          error,
          stackTrace,
        );
        if (restoreGeneration == _restoreGeneration) {
          state = const JellyfinIdle();
        }
      }
    });
    return const JellyfinRestoringSession();
  }

  Future<void> checkServer(String inputUrl) async {
    return _enqueue(() async {
      state = JellyfinVerifyingServer(inputUrl: inputUrl);
      try {
        final server = await ref
            .read(jellyfinAuthRepositoryProvider)
            .validateServer(inputUrl);
        state = JellyfinServerVerified(server: server);
      } on JellyfinApiException catch (error) {
        state = JellyfinSessionFailure(
          kind: error.kind,
          statusCode: error.statusCode,
        );
      } catch (error, stackTrace) {
        AppLogger.error(
          'JellyfinSessionController: Unexpected server validation failure.',
          error,
          stackTrace,
        );
        state = const JellyfinSessionFailure(kind: JellyfinFailureKind.unknown);
      }
    });
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    return _enqueue(() async {
      final current = state;
      if (current is! JellyfinServerVerified) return;

      state = JellyfinSigningIn(server: current.server);
      try {
        final connection = await ref
            .read(jellyfinAuthRepositoryProvider)
            .login(
              server: current.server,
              username: username,
              password: password,
            );
        state = JellyfinAuthenticated(connection: connection);
        ref.invalidate(jellyfinConnectionsProvider);
      } on JellyfinApiException catch (error) {
        state = JellyfinSessionFailure(
          kind: error.kind,
          statusCode: error.statusCode,
          server: current.server,
        );
      } catch (error, stackTrace) {
        AppLogger.error(
          'JellyfinSessionController: Unexpected sign-in failure.',
          error,
          stackTrace,
        );
        state = JellyfinSessionFailure(
          kind: JellyfinFailureKind.unknown,
          server: current.server,
        );
      }
    });
  }

  Future<void> signOut() async {
    return _enqueue(() async {
      final current = state;
      if (current is JellyfinAuthenticated) {
        await ref
            .read(jellyfinAuthRepositoryProvider)
            .logout(current.connection);
      }
      state = const JellyfinIdle();
      ref.invalidate(jellyfinConnectionsProvider);
    });
  }

  Future<void> selectConnection(JellyfinConnection connection) async {
    return _enqueue(() async {
      await ref
          .read(jellyfinCredentialsStoreProvider)
          .select(connection.credentialId);
      state = JellyfinAuthenticated(connection: connection);
      ref.invalidate(jellyfinConnectionsProvider);
    });
  }

  Future<void> startAddingConnection() {
    return _enqueue(() async => state = const JellyfinIdle());
  }

  Future<void> _enqueue(Future<void> Function() action) {
    ++_restoreGeneration;
    final completion = _actionTail.then((_) => action());
    _actionTail = completion.then<void>((_) {}, onError: (_, _) {});
    return completion;
  }
}

final jellyfinSessionControllerProvider =
    NotifierProvider<JellyfinSessionController, JellyfinSessionState>(
      JellyfinSessionController.new,
    );
