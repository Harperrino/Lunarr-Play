import 'dart:async';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';

typedef EpgSyncOperation = Future<void> Function(int playlistId);
typedef EpgClock = DateTime Function();

/// Serial, playlist-aware EPG job controller.
///
/// XMLTV syncs share the same EPG tables. The controller therefore keeps one
/// FIFO queue, while requests for the same playlist share one future and one
/// visible job state.
class EpgSyncController {
  EpgSyncController({required this.sync, EpgClock? now})
    : _now = now ?? DateTime.now;

  final EpgSyncOperation sync;
  final EpgClock _now;
  final List<int> _queue = <int>[];
  final Map<int, EpgSyncJob> _jobs = <int, EpgSyncJob>{};
  final Map<int, Completer<void>> _completions = <int, Completer<void>>{};
  final StreamController<Map<int, EpgSyncJob>> _jobChanges =
      StreamController<Map<int, EpgSyncJob>>.broadcast();
  final StreamController<EpgSyncJob> _events =
      StreamController<EpgSyncJob>.broadcast();
  bool _running = false;
  bool _disposed = false;
  bool _shutdownRequested = false;
  Future<void>? _pumpFuture;
  int _completionRevision = 0;

  int get completionRevision => _completionRevision;

  EpgSyncJob? jobFor(int playlistId) => _jobs[playlistId];

  Stream<Map<int, EpgSyncJob>> watchJobs() async* {
    yield Map<int, EpgSyncJob>.unmodifiable(_jobs);
    yield* _jobChanges.stream;
  }

  Stream<EpgSyncJob> watchEvents() => _events.stream;

  Stream<int> watchCompletionRevisions() async* {
    yield _completionRevision;
    await for (final job in _events.stream) {
      if (job.status == EpgSyncStatus.succeeded) {
        yield _completionRevision;
      }
    }
  }

  /// Adds or joins a playlist job. Same-playlist queued/syncing requests are
  /// deduplicated and receive the same future.
  Future<void> enqueue(
    int playlistId, {
    EpgSyncOrigin origin = EpgSyncOrigin.manual,
  }) {
    if (_disposed || _shutdownRequested) {
      return Future<void>.error(StateError('EPG sync controller is disposed.'));
    }

    final existing = _jobs[playlistId];
    final existingCompletion = _completions[playlistId];
    if (existing != null && existing.isActive && existingCompletion != null) {
      if (origin == EpgSyncOrigin.manual &&
          existing.origin == EpgSyncOrigin.automatic &&
          existing.status == EpgSyncStatus.queued) {
        _updateJob(existing.copyWith(origin: EpgSyncOrigin.manual));
      }
      return existingCompletion.future;
    }

    final job = EpgSyncJob(
      playlistId: playlistId,
      status: EpgSyncStatus.queued,
      origin: origin,
      requestedAt: _now(),
    );
    _jobs[playlistId] = job;
    final completion = Completer<void>();
    _completions[playlistId] = completion;
    // Automatic jobs may be cancelled during shutdown without a live caller
    // awaiting their future. Keep that cancellation from becoming an
    // unhandled asynchronous error while preserving the future for callers.
    unawaited(completion.future.then<void>((_) {}, onError: (_, _) {}));
    _queue.add(playlistId);
    _emit(job);
    _startPump();
    return completion.future;
  }

  void _startPump() {
    if (_pumpFuture != null) return;
    final future = _pump();
    _pumpFuture = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_pumpFuture, future)) _pumpFuture = null;
        },
        onError: (_, _) {
          if (identical(_pumpFuture, future)) _pumpFuture = null;
        },
      ),
    );
  }

  Future<void> _pump() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final playlistId = _queue.removeAt(0);
        final queued = _jobs[playlistId];
        final completion = _completions[playlistId];
        if (queued == null || completion == null) {
          continue;
        }

        final syncing = queued.copyWith(
          status: EpgSyncStatus.syncing,
          startedAt: _now(),
          clearError: true,
        );
        _updateJob(syncing);
        try {
          await sync(playlistId);
          final succeeded = syncing.copyWith(
            status: EpgSyncStatus.succeeded,
            completedAt: _now(),
            clearError: true,
          );
          _updateJob(succeeded);
          _completionRevision++;
          if (!completion.isCompleted) completion.complete();
        } catch (error, stackTrace) {
          final failed = syncing.copyWith(
            status: EpgSyncStatus.failed,
            completedAt: _now(),
            error: error,
          );
          _updateJob(failed);
          if (!completion.isCompleted) {
            completion.completeError(error, stackTrace);
          }
          if (failed.origin == EpgSyncOrigin.automatic) {
            AppLogger.warning(
              'EpgSyncController: Automatic sync failed for playlist '
              '${failed.playlistId}; retry is scheduled by the coordinator.',
            );
          }
        }
      }
    } finally {
      _running = false;
    }
  }

  void _updateJob(EpgSyncJob job) {
    _jobs[job.playlistId] = job;
    _emit(job);
  }

  void _emit(EpgSyncJob job) {
    if (_disposed) return;
    _events.add(job);
    _jobChanges.add(Map<int, EpgSyncJob>.unmodifiable(_jobs));
  }

  /// Stops accepting new work, drops queued jobs, and waits for the one
  /// currently writing SQLite to finish before close is allowed.
  Future<void> drain() async {
    if (_disposed) return;
    _shutdownRequested = true;
    while (_queue.isNotEmpty) {
      final playlistId = _queue.removeLast();
      final completion = _completions[playlistId];
      if (completion != null && !completion.isCompleted) {
        completion.completeError(
          StateError('EPG sync cancelled during shutdown.'),
        );
      }
    }
    final pump = _pumpFuture;
    if (pump != null) {
      try {
        await pump;
      } catch (_) {
        // The per-playlist completion already carries the original error.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await drain();
    _disposed = true;
    for (final completion in _completions.values) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('EPG sync controller disposed.'));
      }
    }
    await _jobChanges.close();
    await _events.close();
  }
}
