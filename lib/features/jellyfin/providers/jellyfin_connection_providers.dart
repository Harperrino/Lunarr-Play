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

/// Credential boundary; memory-only until a verified secure Windows backend
/// exists.
final jellyfinCredentialsStoreProvider = Provider<JellyfinCredentialsStore>(
  (ref) => InMemoryJellyfinCredentialsStore(),
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
  @override
  JellyfinSessionState build() => const JellyfinIdle();

  Future<void> checkServer(String inputUrl) async {
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
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final current = state;
    if (current is! JellyfinServerVerified) return;

    state = JellyfinSigningIn(server: current.server);
    try {
      final connection = await ref
          .read(jellyfinAuthRepositoryProvider)
          .login(server: current.server, username: username, password: password);
      state = JellyfinAuthenticated(connection: connection);
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
  }

  Future<void> signOut() async {
    final current = state;
    if (current is JellyfinAuthenticated) {
      await ref.read(jellyfinAuthRepositoryProvider).logout(current.connection);
    }
    state = const JellyfinIdle();
  }
}

final jellyfinSessionControllerProvider =
    NotifierProvider<JellyfinSessionController, JellyfinSessionState>(
      JellyfinSessionController.new,
    );
