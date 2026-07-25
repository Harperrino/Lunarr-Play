import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/services/epg_auto_refresh_coordinator.dart';
import 'package:m3uxtream_player/core/services/epg_sync_controller.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

/// One serial queue for all EPG writes, exposed as playlist-specific jobs.
final epgSyncControllerProvider = Provider<EpgSyncController>((ref) {
  final controller = EpgSyncController(
    sync: (playlistId) =>
        ref.read(epgSyncServiceProvider).syncEpgForPlaylist(playlistId),
  );
  final completionSubscription = controller.watchEvents().listen((job) {
    if (job.status == EpgSyncStatus.succeeded) {
      ref.read(epgCompletionRevisionProvider.notifier).state++;
    }
  });
  ref.onDispose(() {
    unawaited(completionSubscription.cancel());
    unawaited(controller.dispose());
  });
  return controller;
});

/// All current jobs. A completed job stays visible until a new request for
/// that playlist replaces it, so a closed popup cannot hide the result.
final epgSyncJobsProvider = StreamProvider.autoDispose<Map<int, EpgSyncJob>>(
  (ref) => ref.watch(epgSyncControllerProvider).watchJobs(),
);

/// One-shot lifecycle events used for manual snackbars and automatic logging.
final epgSyncEventsProvider = StreamProvider.autoDispose<EpgSyncJob>(
  (ref) => ref.watch(epgSyncControllerProvider).watchEvents(),
);

/// Changes only after a sync completed successfully; queue/loading transitions
/// never invalidate EPG matching or visible programme providers.
final epgCompletionRevisionProvider = StateProvider<int>((ref) => 0);

final epgRefreshIntervalProvider = StateNotifierProvider.autoDispose
    .family<EpgRefreshIntervalNotifier, EpgRefreshInterval, int>(
      (ref, playlistId) => EpgRefreshIntervalNotifier(
        playlistId,
        ref.read(appStateRepositoryProvider),
        onChanged: () =>
            ref.read(epgAutoRefreshCoordinatorProvider).refreshNow(),
      ),
    );

class EpgRefreshIntervalNotifier extends StateNotifier<EpgRefreshInterval> {
  EpgRefreshIntervalNotifier(
    this.playlistId,
    this._repository, {
    this.onChanged,
  }) : super(EpgRefreshInterval.manual) {
    _load();
  }

  EpgRefreshIntervalNotifier.test(this.playlistId)
    : _repository = null,
      onChanged = null,
      super(EpgRefreshInterval.manual);

  final int playlistId;
  final AppStateRepository? _repository;
  final Future<void> Function()? onChanged;
  bool _userChanged = false;

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;
    final persisted = await repository.getEpgRefreshInterval(playlistId);
    if (mounted && !_userChanged) state = persisted;
  }

  Future<void> setInterval(EpgRefreshInterval interval) async {
    _userChanged = true;
    final previous = state;
    state = interval;
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.setEpgRefreshInterval(playlistId, interval);
      await onChanged?.call();
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final epgAutoRefreshCoordinatorProvider = Provider<EpgAutoRefreshCoordinator>((
  ref,
) {
  final coordinator = EpgAutoRefreshCoordinator(
    controller: ref.watch(epgSyncControllerProvider),
    loadPlaylists: () => ref.read(playlistRepositoryProvider).getAllPlaylists(),
    loadInactivePlaylistIds: () =>
        ref.read(appStateRepositoryProvider).getInactivePlaylistIds(),
    loadInterval: (playlistId) =>
        ref.read(appStateRepositoryProvider).getEpgRefreshInterval(playlistId),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Compatibility facade for older feature boundaries. New code observes the
/// playlist job streams above; this notifier merely forwards manual requests.
class EpgSyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> sync(int playlistId) async {
    AppLogger.info(
      'EpgSyncNotifier: Manual EPG sync requested for Playlist ID: $playlistId.',
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(epgSyncControllerProvider).enqueue(playlistId),
    );
  }
}

final epgSyncNotifierProvider = AsyncNotifierProvider<EpgSyncNotifier, void>(
  EpgSyncNotifier.new,
);
