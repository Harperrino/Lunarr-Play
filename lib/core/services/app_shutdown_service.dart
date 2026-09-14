import 'dart:async';

import 'package:m3uxtream_player/core/logger/app_logger.dart';

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
  /// Stops new database jobs and drains/cancels background work. The default
  /// keeps lightweight test doubles source compatible.
  Future<void> prepareForShutdown() async {}
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
    await _runStep('drain database jobs', _actions.prepareForShutdown);
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
