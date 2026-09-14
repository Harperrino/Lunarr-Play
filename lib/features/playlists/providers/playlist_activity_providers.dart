import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';

/// Persisted inactive playlist IDs (stored in AppStates).
final inactivePlaylistIdsProvider =
    AsyncNotifierProvider<InactivePlaylistIdsNotifier, Set<int>>(
      InactivePlaylistIdsNotifier.new,
    );

class InactivePlaylistIdsNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    return ref.read(appStateRepositoryProvider).getInactivePlaylistIds();
  }

  Future<void> reload() async {
    state = AsyncData(
      await ref.read(appStateRepositoryProvider).getInactivePlaylistIds(),
    );
  }

  Future<void> setActive(int playlistId, bool active) async {
    final repository = ref.read(appStateRepositoryProvider);
    final previousInactiveIds = {
      ...(state.valueOrNull ?? await repository.getInactivePlaylistIds()),
    };
    final inactiveIds = {...previousInactiveIds};

    if (active) {
      inactiveIds.remove(playlistId);
    } else {
      inactiveIds.add(playlistId);
    }

    state = AsyncData(inactiveIds);
    // The activity switch changes exactly this playlist's catalogue scopes;
    // unrelated warm entries stay intact.
    ref
        .read(playlistCatalogWarmCacheProvider)
        .invalidateForPlaylist(playlistId);
    try {
      await repository.setPlaylistActive(playlistId, active);
    } catch (error, stackTrace) {
      // Keep the optimistic UI honest if persistence fails.
      state = AsyncError(error, stackTrace);
      state = AsyncData(previousInactiveIds);
      rethrow;
    }
  }

  Future<void> removePlaylist(int playlistId) async {
    final repository = ref.read(appStateRepositoryProvider);
    final inactiveIds = {
      ...(state.valueOrNull ?? await repository.getInactivePlaylistIds()),
    };
    inactiveIds.remove(playlistId);
    state = AsyncData(inactiveIds);
    ref
        .read(playlistCatalogWarmCacheProvider)
        .invalidateForPlaylist(playlistId);
    await repository.setPlaylistActive(playlistId, true);
  }
}
