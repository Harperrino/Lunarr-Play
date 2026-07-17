import 'package:m3uxtream_player/core/database/app_database.dart';

/// Pure logic for deciding whether the EPG update reminder banner should show.
bool shouldShowEpgReminder({
  required Playlist playlist,
  required bool isDismissed,
  required int? selectedPlaylistId,
}) {
  if (isDismissed) return false;
  if (selectedPlaylistId != playlist.id) return false;

  final epgUrl = playlist.epgUrl;
  if (epgUrl == null || epgUrl.trim().isEmpty) return false;

  final epgLastSynced = playlist.epgLastSyncedAt;
  final lastSynced = playlist.lastSyncedAt;

  if (epgLastSynced == null) return true;
  if (lastSynced == null) return false;

  return epgLastSynced.isBefore(lastSynced);
}

/// Returns the playlist ID that should trigger a reminder after a successful sync,
/// or null when no reminder is needed.
int? resolveEpgReminderPlaylistId({
  required Playlist playlist,
  required bool isDismissed,
}) {
  if (isDismissed) return null;

  final epgUrl = playlist.epgUrl;
  if (epgUrl == null || epgUrl.trim().isEmpty) return null;

  final epgLastSynced = playlist.epgLastSyncedAt;
  final lastSynced = playlist.lastSyncedAt;

  if (epgLastSynced == null) return playlist.id;
  if (lastSynced == null) return null;
  if (epgLastSynced.isBefore(lastSynced)) return playlist.id;

  return null;
}
