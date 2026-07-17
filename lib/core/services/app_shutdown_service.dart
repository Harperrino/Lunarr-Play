import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:window_manager/window_manager.dart';

/// Snapshot of the current series resume state captured before shutdown.
class SeriesResumeSnapshot {
  const SeriesResumeSnapshot({
    required this.playlistId,
    required this.seriesStreamId,
    required this.seriesChannelDbId,
    required this.episodeId,
    required this.episodeTitle,
    required this.streamUrl,
    required this.positionMs,
    this.season,
    this.episodeNum,
  });

  final int playlistId;
  final String seriesStreamId;
  final int seriesChannelDbId;
  final String episodeId;
  final String episodeTitle;
  final String streamUrl;
  final int positionMs;
  final int? season;
  final int? episodeNum;
}

abstract class AppShutdownActions {
  Future<void> exitFullscreenIfNeeded();
  Future<SeriesResumeSnapshot?> captureSeriesResumeSnapshot();
  Future<void> stopPlayback();
  Future<void> saveSeriesResume(SeriesResumeSnapshot snapshot);
  Future<void> disposePlaybackResources();
  Future<void> closeDatabase();
  Future<void> destroyWindow();
}

/// Idempotent app shutdown coordinator.
class AppShutdownController {
  AppShutdownController(this._actions);

  final AppShutdownActions _actions;
  Future<void>? _shutdownFuture;
  bool _completed = false;

  Future<void> requestShutdown({required String reason}) {
    if (_completed) return _shutdownFuture ?? Future.value();
    final existing = _shutdownFuture;
    if (existing != null) return existing;

    final future = _run(reason);
    _shutdownFuture = future;
    return future;
  }

  Future<void> _run(String reason) async {
    AppLogger.info('AppShutdown: Shutdown started ($reason).');

    final seriesSnapshot = await _safeCaptureSeriesSnapshot();

    await _runStep('exit fullscreen', _actions.exitFullscreenIfNeeded);
    await _runStep('stop playback', _actions.stopPlayback);

    if (seriesSnapshot != null) {
      await _runStep(
        'save series resume',
        () => _actions.saveSeriesResume(seriesSnapshot),
      );
    }

    await _runStep(
      'dispose playback resources',
      _actions.disposePlaybackResources,
    );
    await _runStep('close database', _actions.closeDatabase);
    await _runStep('destroy window', _actions.destroyWindow);

    AppLogger.info('AppShutdown: Shutdown completed ($reason).');
    _completed = true;
  }

  Future<SeriesResumeSnapshot?> _safeCaptureSeriesSnapshot() async {
    try {
      return await _actions.captureSeriesResumeSnapshot();
    } catch (e, stackTrace) {
      AppLogger.error(
        'AppShutdown: Failed to capture series resume snapshot',
        e,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _runStep(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (e, stackTrace) {
      AppLogger.error('AppShutdown: Step failed - $label', e, stackTrace);
    }
  }
}

class RiverpodAppShutdownActions implements AppShutdownActions {
  RiverpodAppShutdownActions(this.ref);

  final Ref ref;

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
    await ref.read(playerNotifierProvider.notifier).stopStream();
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
    await ref.read(playerNotifierProvider.notifier).disposeResources();
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
      // Windows fallback: some native plugin threads can keep the process alive
      // briefly after the window is destroyed, so force termination only after
      // playback, persistence, and player cleanup have already completed.
      exit(0);
    }
  }
}
