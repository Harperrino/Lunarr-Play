import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Playlist-specific hidden-category read boundary. Unlike the legacy active
/// notifier this family can be loaded for several All-scope playlists in
/// parallel without mutating a global selected-playlist state.
final hiddenGroupsForPlaylistProvider = FutureProvider.autoDispose
    .family<Set<String>, int>((ref, playlistId) {
      return ref.read(appStateRepositoryProvider).getHiddenGroups(playlistId);
    });

/// Hidden category names for the active playlist (persisted in AppStates).
final hiddenGroupsProvider =
    AsyncNotifierProvider<HiddenGroupsNotifier, Set<String>>(
      HiddenGroupsNotifier.new,
    );

class HiddenGroupsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final playlistId = ref.watch(selectedPlaylistIdProvider);
    if (playlistId == null) return {};
    return ref.read(appStateRepositoryProvider).getHiddenGroups(playlistId);
  }

  Future<void> reloadForPlaylist(int playlistId) async {
    state = AsyncData(
      await ref.read(appStateRepositoryProvider).getHiddenGroups(playlistId),
    );
  }

  Future<void> setHidden(int playlistId, Set<String> hidden) async {
    await ref
        .read(appStateRepositoryProvider)
        .setHiddenGroups(playlistId, hidden);
    if (ref.read(selectedPlaylistIdProvider) == playlistId) {
      state = AsyncData(hidden);
    }
    ref.invalidate(hiddenGroupsForPlaylistProvider(playlistId));
  }

  Future<void> toggleGroup(
    int playlistId,
    String groupName,
    bool visible,
  ) async {
    final current = {...(state.valueOrNull ?? {})};
    if (visible) {
      current.remove(groupName);
    } else {
      current.add(groupName);
    }
    await setHidden(playlistId, current);
  }
}
