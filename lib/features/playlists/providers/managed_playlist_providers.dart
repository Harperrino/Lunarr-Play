import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// Explicit category read models for the management-focused playlist.
/// Playback selection is never consulted by these providers.
final managedPlaylistChannelsProvider = StreamProvider.autoDispose
    .family<List<Channel>, int>((ref, playlistId) {
      return ref
          .watch(playlistRepositoryProvider)
          .watchChannelsByPlaylist(playlistId);
    });

final managedHiddenGroupsProvider = FutureProvider.autoDispose
    .family<Set<String>, int>((ref, playlistId) {
      return ref.watch(appStateRepositoryProvider).getHiddenGroups(playlistId);
    });

final managedPinnedGroupsProvider = FutureProvider.autoDispose
    .family<List<String>, int>((ref, playlistId) {
      return ref.watch(appStateRepositoryProvider).getPinnedGroups(playlistId);
    });

int? managementPlaylistId({
  required List<Playlist> playlists,
  required Set<int> inactiveIds,
  required int? managedId,
  required int? selectedId,
}) {
  if (managedId != null &&
      playlists.any((playlist) => playlist.id == managedId)) {
    return managedId;
  }
  if (selectedId != null &&
      playlists.any((playlist) => playlist.id == selectedId)) {
    return selectedId;
  }
  for (final playlist in playlists) {
    if (!inactiveIds.contains(playlist.id)) return playlist.id;
  }
  return playlists.isEmpty ? null : playlists.first.id;
}
