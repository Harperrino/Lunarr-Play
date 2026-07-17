import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/playlist_sync_service.dart';

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository(ref.watch(databaseProvider));
});

final playlistSyncServiceProvider = Provider<PlaylistSyncService>((ref) {
  return PlaylistSyncService(ref.watch(playlistRepositoryProvider));
});

/// Currently active playlist whose channels are shown in the UI.
final selectedPlaylistIdProvider = StateProvider<int?>((ref) => null);

/// Reactive stream of all persisted playlists from Drift.
final playlistsStreamProvider = StreamProvider.autoDispose<List<Playlist>>((
  ref,
) {
  return ref.watch(playlistRepositoryProvider).watchAllPlaylists();
});

List<Playlist> activePlaylists(List<Playlist> playlists, Set<int> inactiveIds) {
  return playlists
      .where((playlist) => !inactiveIds.contains(playlist.id))
      .toList(growable: false);
}

int? firstActivePlaylistId(List<Playlist> playlists, Set<int> inactiveIds) {
  for (final playlist in playlists) {
    if (!inactiveIds.contains(playlist.id)) {
      return playlist.id;
    }
  }
  return null;
}

void normalizeSelectedPlaylist(
  WidgetRef ref,
  List<Playlist> playlists,
  Set<int> inactiveIds,
) {
  final current = ref.read(selectedPlaylistIdProvider);
  final exists =
      current != null && playlists.any((playlist) => playlist.id == current);
  final isActive = current != null && exists && !inactiveIds.contains(current);

  if (isActive) return;

  final fallback = firstActivePlaylistId(playlists, inactiveIds);
  if (current != fallback) {
    ref.read(selectedPlaylistIdProvider.notifier).state = fallback;
  }
}
