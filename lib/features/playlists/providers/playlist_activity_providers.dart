import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';

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
    final inactiveIds = {
      ...(state.valueOrNull ?? await repository.getInactivePlaylistIds()),
    };

    if (active) {
      inactiveIds.remove(playlistId);
    } else {
      inactiveIds.add(playlistId);
    }

    await repository.setPlaylistActive(playlistId, active);
    state = AsyncData(inactiveIds);
  }

  Future<void> removePlaylist(int playlistId) async {
    final repository = ref.read(appStateRepositoryProvider);
    final inactiveIds = {
      ...(state.valueOrNull ?? await repository.getInactivePlaylistIds()),
    };
    inactiveIds.remove(playlistId);
    await repository.setPlaylistActive(playlistId, true);
    state = AsyncData(inactiveIds);
  }
}
