import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';

/// Reactive sync controller for EPG refresh operations.
class EpgSyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Triggers EPG sync for the given playlist (reads URL from playlist record).
  Future<void> sync(int playlistId) async {
    AppLogger.info(
      'EpgSyncNotifier: EPG sync requested for Playlist ID: $playlistId.',
    );
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref.read(epgSyncServiceProvider).syncEpgForPlaylist(playlistId);
      AppLogger.info(
        'EpgSyncNotifier: EPG sync completed for Playlist ID: $playlistId.',
      );
    });
  }
}

final epgSyncNotifierProvider = AsyncNotifierProvider<EpgSyncNotifier, void>(
  EpgSyncNotifier.new,
);
