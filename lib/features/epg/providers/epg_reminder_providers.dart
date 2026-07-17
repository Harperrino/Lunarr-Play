import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/epg_reminder_logic.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';

/// Playlist ID for which the EPG update reminder banner should be shown, or null.
final epgUpdateReminderProvider = StateProvider<int?>((ref) => null);

/// Tracks dismissed state per playlist (loaded from AppStates on demand).
final epgReminderDismissedProvider = StateProvider.family<bool, int>(
  (ref, playlistId) => false,
);

/// Initializes reminder listeners — call once from [ChannelListPanel].
void listenEpgReminderOrchestration(WidgetRef ref) {
  ref.listen(playlistSyncNotifierProvider, (previous, next) async {
    if (previous?.isLoading != true || !next.hasValue || next.hasError) return;

    final selectedId = ref.read(selectedPlaylistIdProvider);
    if (selectedId == null) return;

    final playlist = await ref
        .read(playlistRepositoryProvider)
        .getPlaylistById(selectedId);
    if (playlist == null) return;

    final dismissed = await ref
        .read(appStateRepositoryProvider)
        .isEpgReminderDismissed(selectedId);
    ref.read(epgReminderDismissedProvider(selectedId).notifier).state =
        dismissed;

    final reminderId = resolveEpgReminderPlaylistId(
      playlist: playlist,
      isDismissed: dismissed,
    );
    ref.read(epgUpdateReminderProvider.notifier).state = reminderId;

    if (reminderId != null) {
      AppLogger.info(
        'EpgReminder: Showing update banner for playlist ID: $reminderId.',
      );
    }
  });

  ref.listen(epgSyncNotifierProvider, (previous, next) async {
    if (previous?.isLoading != true || !next.hasValue || next.hasError) return;

    final reminderId = ref.read(epgUpdateReminderProvider);
    if (reminderId != null) {
      await ref
          .read(appStateRepositoryProvider)
          .clearEpgReminderDismissed(reminderId);
      ref.read(epgReminderDismissedProvider(reminderId).notifier).state = false;
      ref.read(epgUpdateReminderProvider.notifier).state = null;
      AppLogger.info(
        'EpgReminder: Cleared banner after successful EPG sync for playlist ID: $reminderId.',
      );
    }
  });
}

/// Dismisses the EPG reminder for [playlistId] and persists the choice.
Future<void> dismissEpgReminder(WidgetRef ref, int playlistId) async {
  await ref
      .read(appStateRepositoryProvider)
      .setEpgReminderDismissed(playlistId, true);
  ref.read(epgReminderDismissedProvider(playlistId).notifier).state = true;
  ref.read(epgUpdateReminderProvider.notifier).state = null;
  AppLogger.info(
    'EpgReminder: User dismissed banner for playlist ID: $playlistId.',
  );
}

/// Whether the banner should render for the current selection.
bool watchEpgReminderVisible(WidgetRef ref) {
  final reminderId = ref.watch(epgUpdateReminderProvider);
  final selectedId = ref.watch(selectedPlaylistIdProvider);
  if (reminderId == null || selectedId != reminderId) return false;

  final dismissed = ref.watch(epgReminderDismissedProvider(reminderId));
  if (dismissed) return false;

  final playlists = ref.watch(playlistsStreamProvider).valueOrNull;
  if (playlists == null) return false;

  Playlist? playlist;
  for (final p in playlists) {
    if (p.id == reminderId) {
      playlist = p;
      break;
    }
  }
  if (playlist == null) return false;

  return shouldShowEpgReminder(
    playlist: playlist,
    isDismissed: dismissed,
    selectedPlaylistId: selectedId,
  );
}
