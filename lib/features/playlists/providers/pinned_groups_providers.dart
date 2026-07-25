import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Playlist-specific pinned-category read boundary for All-active catalogs.
final pinnedGroupsForPlaylistProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, playlistId) {
      return ref.read(appStateRepositoryProvider).getPinnedGroups(playlistId);
    });

/// Pinned category names for the active playlist (persisted in AppStates).
///
/// The list order is the display order used for pinned groups.
final pinnedGroupsProvider =
    AsyncNotifierProvider<PinnedGroupsNotifier, List<String>>(
      PinnedGroupsNotifier.new,
    );

class PinnedGroupsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final playlistId = ref.watch(selectedPlaylistIdProvider);
    if (playlistId == null) return const [];
    return ref.read(appStateRepositoryProvider).getPinnedGroups(playlistId);
  }

  Future<void> reloadForPlaylist(int playlistId) async {
    state = AsyncData(
      await ref.read(appStateRepositoryProvider).getPinnedGroups(playlistId),
    );
  }

  Future<void> setPinned(int playlistId, List<String> pinned) async {
    await ref
        .read(appStateRepositoryProvider)
        .setPinnedGroups(playlistId, pinned);
    if (ref.read(selectedPlaylistIdProvider) == playlistId) {
      state = AsyncData(pinned);
    }
    ref.invalidate(pinnedGroupsForPlaylistProvider(playlistId));
  }

  Future<void> toggleGroup(
    int playlistId,
    String groupName,
    bool pinned,
  ) async {
    final current = [...(state.valueOrNull ?? const <String>[])];
    if (pinned) {
      current.remove(groupName);
      current.add(groupName);
    } else {
      current.remove(groupName);
    }
    await setPinned(playlistId, current);
  }
}
