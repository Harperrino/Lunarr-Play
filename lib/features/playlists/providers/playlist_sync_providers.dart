import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Shared per-playlist status surface. The legacy global notifier below is
/// retained as a compatibility façade for existing callers, while all new UI
/// observes this targeted state.
final playlistSyncStatusProvider = StateProvider.family<AsyncValue<void>, int>(
  (ref, playlistId) => const AsyncData(null),
);

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
    final lifecycleGate = ref.read(appLifecycleGateProvider);
    lifecycleGate.ensureWritable();
    AppLogger.info(
      'PlaylistSyncNotifier: Sync requested for Playlist ID: $playlistId.',
    );
    final targetedStatus = ref.read(
      playlistSyncStatusProvider(playlistId).notifier,
    );
    targetedStatus.state = const AsyncLoading();
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() async {
      await lifecycleGate.runTracked(
        () => ref.read(playlistSyncServiceProvider).syncPlaylist(playlistId),
      );
      // The sync replaced exactly this playlist's channels; only its warm
      // catalogue entries become stale, never the whole cache.
      ref
          .read(playlistCatalogWarmCacheProvider)
          .invalidateForPlaylist(playlistId);
      AppLogger.info(
        'PlaylistSyncNotifier: Sync completed for Playlist ID: $playlistId.',
      );
    });
    targetedStatus.state = result;
    state = result;
  }
}

final playlistSyncNotifierProvider =
    AsyncNotifierProvider<PlaylistSyncNotifier, void>(PlaylistSyncNotifier.new);
