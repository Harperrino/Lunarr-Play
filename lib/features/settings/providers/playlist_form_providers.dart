import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

/// Outcome of a playlist form submission.
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

/// Handles playlist insert and delete operations — no UI logic.
class PlaylistFormNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<PlaylistFormResult> addM3uPlaylist({
    required String name,
    required String urlOrPath,
  }) async {
    final trimmedName = name.trim();
    final trimmedUrl = urlOrPath.trim();

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
        epgUrl: Value(epgUrl?.trim().isEmpty ?? true ? null : epgUrl!.trim()),
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
      AppLogger.warning('PlaylistFormNotifier: Validation failed â€” $message');
      return const PlaylistFormValidationError(message);
    }

    if (type == 'xtream' &&
        (trimmedUsername == null ||
            trimmedUsername.isEmpty ||
            trimmedPassword == null ||
            trimmedPassword.isEmpty)) {
      const message = 'All Xtream fields are required.';
      AppLogger.warning('PlaylistFormNotifier: Validation failed â€” $message');
      return const PlaylistFormValidationError(message);
    }

    state = const AsyncLoading();

    try {
      final companion = type == 'xtream'
          ? PlaylistsCompanion(
              name: Value(trimmedName),
              urlOrHost: Value(trimmedUrl),
              username: Value(trimmedUsername),
              password: Value(trimmedPassword),
              epgUrl: Value(
                trimmedEpgUrl == null || trimmedEpgUrl.isEmpty
                    ? null
                    : trimmedEpgUrl,
              ),
            )
          : PlaylistsCompanion(
              name: Value(trimmedName),
              urlOrHost: Value(trimmedUrl),
            );

      await ref
          .read(playlistRepositoryProvider)
          .updatePlaylist(playlistId: playlistId, playlist: companion);

      AppLogger.info(
        'PlaylistFormNotifier: Updated playlist "$trimmedName" (ID: $playlistId).',
      );
      state = const AsyncData(null);
      return PlaylistFormSuccess(playlistId, trimmedName);
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistFormNotifier: Failed to update playlist ID: $playlistId',
        e,
        stackTrace,
      );
      state = AsyncError(e, stackTrace);
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
      AppLogger.info(
        'PlaylistFormNotifier: Inserted playlist "$playlistName" (ID: $id).',
      );

      ref.read(selectedPlaylistIdProvider.notifier).state = id;
      await ref.read(playlistSyncNotifierProvider.notifier).sync(id);

      state = const AsyncData(null);
      return PlaylistFormSuccess(id, playlistName);
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistFormNotifier: Failed to add playlist',
        e,
        stackTrace,
      );
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }

  Future<void> deletePlaylist(int playlistId) async {
    state = const AsyncLoading();

    try {
      final selectedId = ref.read(selectedPlaylistIdProvider);
      final selectedChannel = ref.read(selectedChannelProvider);

      if (selectedChannel != null && selectedChannel.playlistId == playlistId) {
        ref.read(selectedChannelProvider.notifier).state = null;
        AppLogger.info(
          'PlaylistFormNotifier: Cleared active channel (deleted playlist).',
        );
      }

      await ref.read(playlistRepositoryProvider).deletePlaylist(playlistId);
      AppLogger.info('PlaylistFormNotifier: Deleted playlist ID: $playlistId.');
      await ref
          .read(inactivePlaylistIdsProvider.notifier)
          .removePlaylist(playlistId);

      if (selectedId == playlistId) {
        final remaining = await ref
            .read(playlistRepositoryProvider)
            .getAllPlaylists();
        final inactiveIds =
            ref.read(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
        final fallbackId = firstActivePlaylistId(remaining, inactiveIds);
        ref.read(selectedPlaylistIdProvider.notifier).state = fallbackId;
        AppLogger.info(
          'PlaylistFormNotifier: Updated selectedPlaylistId → ${fallbackId ?? "null"}.',
        );
      }

      state = const AsyncData(null);
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistFormNotifier: Failed to delete playlist ID: $playlistId',
        e,
        stackTrace,
      );
      state = AsyncError(e, stackTrace);
      rethrow;
    }
  }
}

final playlistFormNotifierProvider =
    AsyncNotifierProvider<PlaylistFormNotifier, void>(PlaylistFormNotifier.new);
