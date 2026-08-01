import 'dart:math';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_server_info.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_log_redactor.dart';

/// Orchestrates server validation, login and logout.
///
/// The access token is handed to the [JellyfinCredentialsStore] and is never
/// logged, persisted in plaintext or mirrored into Drift.
class JellyfinAuthRepository {
  JellyfinAuthRepository({
    required this._apiClient,
    required this._credentialsStore,
  });

  final JellyfinApiClient _apiClient;
  final JellyfinCredentialsStore _credentialsStore;
  final JellyfinLogRedactor _redactor = const JellyfinLogRedactor();

  late final String _deviceId = _generateDeviceId();

  /// Normalizes [inputUrl] and fetches the public server info.
  Future<JellyfinServerInfo> validateServer(String inputUrl) {
    return _apiClient.fetchPublicServerInfo(inputUrl);
  }

  /// Authenticates against [server] and stores the resulting session.
  Future<JellyfinConnection> login({
    required JellyfinServerInfo server,
    required String username,
    required String password,
  }) async {
    final authentication = await _apiClient.authenticateByName(
      baseUrl: server.baseUrl,
      username: username,
      password: password,
      deviceId: _deviceId,
    );

    final connection = JellyfinConnection(
      baseUrl: server.baseUrl,
      serverId: authentication.serverId,
      serverVersion: server.serverVersion,
      userId: authentication.userId,
      username: authentication.username,
      accessToken: authentication.accessToken,
      deviceId: _deviceId,
    );

    await _credentialsStore.write(connection);
    AppLogger.info(
      _redactor.redact(
        'JellyfinAuthRepository: Session stored for ${connection.baseUrl}.',
      ),
    );
    return connection;
  }

  /// Ends the server session and always clears the local credential store.
  Future<void> logout(JellyfinConnection connection) async {
    try {
      await _apiClient.logout(connection);
    } on JellyfinApiException catch (error) {
      AppLogger.warning(
        'JellyfinAuthRepository: Server logout failed '
        '(${error.kind.name}). Local credentials are cleared anyway.',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'JellyfinAuthRepository: Server logout failed. '
        'Local credentials are cleared anyway.',
        error,
        stackTrace,
      );
    } finally {
      await _credentialsStore.clear();
    }
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
