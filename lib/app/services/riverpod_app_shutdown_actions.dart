import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/shared/providers/app_shell_state_providers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/services/app_shutdown_service.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';
import 'package:window_manager/window_manager.dart';

/// App-layer adapter that coordinates Riverpod feature implementations while
/// the shutdown contract and ordering remain independent in `core`.
class RiverpodAppShutdownActions implements AppShutdownActions {
  RiverpodAppShutdownActions(this.ref);

  final Ref ref;

  /// Fixed shutdown order for database-backed work:
  /// 1. close the lifecycle gate (new operations are rejected),
  /// 2. stop the auto-EPG coordinator and schedulers,
  /// 3. drain the serial EPG queue,
  /// 4. drain search-index and repository jobs,
  /// 5. dispose the search/EPG services,
  /// 6. only afterwards may [closeDatabase] close SQLite.
  @override
  Future<void> prepareForShutdown() async {
    final gate = ref.read(appLifecycleGateProvider);
    gate.beginShutdown();

    await ref.read(epgAutoRefreshCoordinatorProvider).dispose();
    final epgController = ref.read(epgSyncControllerProvider);
    await epgController.drain();

    final searchIndex = ref.read(searchIndexRepositoryProvider);
    searchIndex.beginShutdown();
    await searchIndex.drain();
    await gate.drain();
    await searchIndex.dispose();
    await epgController.dispose();
  }

  @override
  Future<void> exitFullscreenIfNeeded() async {
    if (!ref.read(isDesktopPlatformProvider)) return;

    try {
      if (await windowManager.isFullScreen()) {
        ref.read(isFullscreenProvider.notifier).state = false;
        await windowManager.setFullScreen(false);
      }
    } catch (e, stackTrace) {
      AppLogger.error('AppShutdown: Failed to exit fullscreen', e, stackTrace);
    }
  }

  @override
  Future<SeriesResumeSnapshot?> captureSeriesResumeSnapshot() async {
    final activeSeries = ref.read(seriesActivePlaybackProvider);
    if (activeSeries == null) return null;

    final playerState = ref.read(playerNotifierProvider).valueOrNull;
    if (playerState == null) return null;

    final positionMs = playerState.position.inMilliseconds;
    if (positionMs <= 0) return null;

    return SeriesResumeSnapshot(
      playlistId: activeSeries.playlistId,
      seriesStreamId: activeSeries.seriesStreamId,
      seriesChannelDbId: activeSeries.seriesChannelDbId,
      episodeId: activeSeries.episode.episodeId,
      episodeTitle: activeSeries.episode.title,
      streamUrl: activeSeries.episode.streamUrl,
      positionMs: positionMs,
      season: activeSeries.episode.season,
      episodeNum: activeSeries.episode.episodeNum,
    );
  }

  @override
  Future<void> stopPlayback() async {
    try {
      await ref.read(playerNotifierProvider.notifier).stopStream();
    } finally {
      await _stopJellyfinPlaybackIfActive();
    }
  }

  @override
  Future<void> saveSeriesResume(SeriesResumeSnapshot snapshot) async {
    await ref
        .read(appStateRepositoryProvider)
        .setSeriesResume(
          snapshot.playlistId,
          snapshot.seriesStreamId,
          SeriesResumeState(
            episodeId: snapshot.episodeId,
            episodeTitle: snapshot.episodeTitle,
            streamUrl: snapshot.streamUrl,
            positionMs: snapshot.positionMs,
            season: snapshot.season,
            episodeNum: snapshot.episodeNum,
          ),
        );

    ref.invalidate(seriesResumeProvider(snapshot.seriesChannelDbId));
  }

  @override
  Future<void> disposePlaybackResources() async {
    try {
      await ref.read(playerNotifierProvider.notifier).disposeResources();
    } finally {
      await _disposeJellyfinPlaybackIfActive();
    }
  }

  Future<void> _stopJellyfinPlaybackIfActive() async {
    if (!ref.exists(jellyfinPlayerControllerProvider)) return;
    await ref.read(jellyfinPlayerControllerProvider).stop();
  }

  Future<void> _disposeJellyfinPlaybackIfActive() async {
    if (!ref.exists(jellyfinPlayerControllerProvider)) return;
    await ref.read(jellyfinPlayerControllerProvider).disposeAsync();
  }

  @override
  Future<void> closeDatabase() async {
    await ref.read(databaseProvider).close();
  }

  @override
  Future<void> destroyWindow() async {
    if (!ref.read(isDesktopPlatformProvider)) return;

    await windowManager.destroy();

    if (Platform.isWindows) {
      exit(0);
    }
  }
}
