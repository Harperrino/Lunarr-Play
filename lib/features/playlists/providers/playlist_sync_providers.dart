import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Reactive sync controller for playlist refresh operations.
/// Sets [AsyncLoading] while [PlaylistSyncService] runs isolate-based parsing.
class PlaylistSyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    // Idle — no sync in progress on startup.
  }

  /// Triggers a full sync for the given playlist ID.
  /// Network fetch runs on the main isolate; parsing is offloaded via [Isolate.run] inside the service.
  Future<void> sync(int playlistId) async {
    AppLogger.info(
      'PlaylistSyncNotifier: Sync requested for Playlist ID: $playlistId.',
    );
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref.read(playlistSyncServiceProvider).syncPlaylist(playlistId);
      AppLogger.info(
        'PlaylistSyncNotifier: Sync completed for Playlist ID: $playlistId.',
      );
    });
  }
}

final playlistSyncNotifierProvider =
    AsyncNotifierProvider<PlaylistSyncNotifier, void>(PlaylistSyncNotifier.new);
