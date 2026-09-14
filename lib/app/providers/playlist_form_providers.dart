import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/app/controllers/playlist_management_controller.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';

sealed class PlaylistFormResult {
  const PlaylistFormResult();
}

class PlaylistFormSuccess extends PlaylistFormResult {
  const PlaylistFormSuccess(this.playlistId, this.playlistName);

  final int playlistId;
  final String playlistName;
}

class PlaylistFormValidationError extends PlaylistFormResult {
  const PlaylistFormValidationError(this.message);

  final String message;
}

/// Playlist CRUD boundary owned by the Playlist feature rather than Settings.
class PlaylistFormNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<PlaylistFormResult> addM3uPlaylist({
    required String name,
    required String urlOrPath,
    String? epgUrlOverride,
  }) async {
    final trimmedName = name.trim();
    final trimmedUrl = urlOrPath.trim();
    final trimmedEpgUrl = epgUrlOverride?.trim();
    if (trimmedName.isEmpty || trimmedUrl.isEmpty) {
      const message = 'Name and URL/path are required.';
      AppLogger.warning('PlaylistFormNotifier: Validation failed — $message');
      return const PlaylistFormValidationError(message);
    }

    return _insertAndSync(
      companion: PlaylistsCompanion.insert(
        name: trimmedName,
        type: 'm3u',
        urlOrHost: trimmedUrl,
        epgUrlOverride: Value(
          trimmedEpgUrl == null || trimmedEpgUrl.isEmpty ? null : trimmedEpgUrl,
        ),
      ),
      playlistName: trimmedName,
    );
  }

  Future<PlaylistFormResult> addXtreamPlaylist({
    required String name,
    required String host,
    required String username,
    required String password,
    String? epgUrl,
  }) async {
    final trimmedName = name.trim();
    final trimmedHost = host.trim();
    final trimmedUser = username.trim();
    final trimmedPass = password.trim();
    final trimmedEpgUrl = epgUrl?.trim();

    if (trimmedName.isEmpty ||
        trimmedHost.isEmpty ||
        trimmedUser.isEmpty ||
        trimmedPass.isEmpty) {
      const message = 'All Xtream fields are required.';
      AppLogger.warning('PlaylistFormNotifier: Validation failed — $message');
      return const PlaylistFormValidationError(message);
    }

    return _insertAndSync(
      companion: PlaylistsCompanion.insert(
        name: trimmedName,
        type: 'xtream',
        urlOrHost: trimmedHost,
        username: Value(trimmedUser),
        password: Value(trimmedPass),
        epgUrlOverride: Value(
          trimmedEpgUrl == null || trimmedEpgUrl.isEmpty ? null : trimmedEpgUrl,
        ),
      ),
      playlistName: trimmedName,
    );
  }

  Future<PlaylistFormResult> updatePlaylist({
    required int playlistId,
    required String type,
    required String name,
    required String urlOrPath,
    String? username,
    String? password,
    String? epgUrl,
  }) async {
    final trimmedName = name.trim();
    final trimmedUrl = urlOrPath.trim();
    final trimmedUsername = username?.trim();
    final trimmedPassword = password?.trim();
    final trimmedEpgUrl = epgUrl?.trim();

    if (trimmedName.isEmpty || trimmedUrl.isEmpty) {
      const message = 'Name and URL/path are required.';
      return const PlaylistFormValidationError(message);
    }
    if (type == 'xtream' &&
        (trimmedUsername == null ||
            trimmedUsername.isEmpty ||
            trimmedPassword == null ||
            trimmedPassword.isEmpty)) {
      const message = 'All Xtream fields are required.';
      return const PlaylistFormValidationError(message);
    }

    state = const AsyncLoading();
    try {
      await ref
          .read(playlistRepositoryProvider)
          .updatePlaylist(
            playlistId: playlistId,
            playlist: PlaylistsCompanion(
              name: Value(trimmedName),
              urlOrHost: Value(trimmedUrl),
              username: type == 'xtream'
                  ? Value(trimmedUsername)
                  : const Value.absent(),
              password: type == 'xtream'
                  ? Value(trimmedPassword)
                  : const Value.absent(),
              epgUrlOverride: Value(
                trimmedEpgUrl == null || trimmedEpgUrl.isEmpty
                    ? null
                    : trimmedEpgUrl,
              ),
            ),
          );
      state = const AsyncData(null);
      return PlaylistFormSuccess(playlistId, trimmedName);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<PlaylistFormResult> _insertAndSync({
    required PlaylistsCompanion companion,
    required String playlistName,
  }) async {
    state = const AsyncLoading();
    try {
      final id = await ref
          .read(playlistRepositoryProvider)
          .insertPlaylist(companion);
      await ref.read(playlistManagementControllerProvider).selectPlaylist(id);
      await ref.read(playlistSyncNotifierProvider.notifier).sync(id);
      state = const AsyncData(null);
      return PlaylistFormSuccess(id, playlistName);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(playlistManagementControllerProvider)
          .deletePlaylist(playlistId);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final playlistFormNotifierProvider =
    AsyncNotifierProvider<PlaylistFormNotifier, void>(PlaylistFormNotifier.new);
