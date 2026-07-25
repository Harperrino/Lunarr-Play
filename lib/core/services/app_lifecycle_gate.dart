import 'dart:async';

import 'package:flutter/foundation.dart';

/// Small process-lifetime boundary shared by database-backed jobs.
///
/// The UI can optimistically update its in-memory state while this gate is
/// open. Once shutdown starts, new persistence work is rejected and already
/// running operations can be drained before the SQLite connection is closed.
class AppLifecycleGate {
  final Set<Future<void>> _runningJobs = <Future<void>>{};
  bool _shutdownStarted = false;

  bool get isShutdownStarted => _shutdownStarted;

  /// Number of currently registered jobs. Exposed for lifecycle tests only.
  @visibleForTesting
  int get trackedJobCount => _runningJobs.length;

  void beginShutdown() {
    _shutdownStarted = true;
  }

  void ensureWritable() {
    if (_shutdownStarted) {
      throw StateError(
        'Database writes are disabled during application shutdown.',
      );
    }
  }

  /// Atomically rejects a started shutdown, starts [operation], registers it
  /// and unregisters it again once it settles successfully or with an error.
  ///
  /// Dart runs this sequence without interruption, so [beginShutdown] can
  /// never slip between the writability check and the registration. The
  /// returned future carries the operation's own result and errors; the
  /// internal tracking future swallows errors so a failed job neither blocks
  /// [drain] nor escapes as an unhandled asynchronous exception.
  Future<T> runTracked<T>(Future<T> Function() operation) {
    ensureWritable();
    final job = operation();
    return track(job);
  }

  /// Tracks a database-backed job until it settles.
  Future<T> track<T>(Future<T> job) {
    // The tracking future must never surface the original error as an
    // unhandled asynchronous exception. The caller still receives [job] and
    // therefore retains normal error semantics.
    final completion = job.then<void>((_) {}, onError: (_, _) {});
    _runningJobs.add(completion);
    completion.then<void>((_) => _runningJobs.remove(completion));
    return job;
  }

  Future<void> drain() async {
    while (_runningJobs.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_runningJobs));
    }
  }
}
