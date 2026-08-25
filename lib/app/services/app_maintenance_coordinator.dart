import 'dart:async';

typedef AppMaintenanceTask = Future<void> Function();
typedef AppMaintenanceClock = DateTime Function();
typedef AppMaintenanceDelay = Future<void> Function(Duration duration);

/// Serializes best-effort maintenance and waits for recent UI transitions.
///
/// This coordinator deliberately owns no repositories. App composition queues
/// search/EPG work here without coupling either subsystem to shell state.
class AppMaintenanceCoordinator {
  AppMaintenanceCoordinator({
    AppMaintenanceClock? now,
    AppMaintenanceDelay? delay,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final AppMaintenanceClock _now;
  final AppMaintenanceDelay _delay;
  final Set<Object> _pendingKeys = <Object>{};
  Future<void> _tail = Future<void>.value();
  DateTime? _notBefore;
  bool _disposed = false;

  void deferFor(Duration duration) {
    if (_disposed || duration <= Duration.zero) return;
    final candidate = _now().add(duration);
    final current = _notBefore;
    if (current == null || candidate.isAfter(current)) {
      _notBefore = candidate;
    }
  }

  Future<void> schedule(AppMaintenanceTask task, {Object? key}) {
    if (_disposed) return Future<void>.value();
    if (key != null && !_pendingKeys.add(key)) return Future<void>.value();

    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await _waitForIdleWindow();
        if (!_disposed) await task();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        if (key != null) _pendingKeys.remove(key);
      }
    });
    // A failing task is reported to its caller but never poisons the queue.
    _tail = _tail.catchError((_) {});
    return completer.future;
  }

  /// Allows a long-running maintenance job to yield at safe transaction
  /// boundaries and observe a newer UI deferral before continuing.
  Future<void> waitUntilIdle() => _waitForIdleWindow();

  Future<void> _waitForIdleWindow() async {
    while (!_disposed) {
      final target = _notBefore;
      if (target == null) return;
      final remaining = target.difference(_now());
      if (remaining <= Duration.zero) {
        if (_notBefore == target) _notBefore = null;
        return;
      }
      await _delay(remaining);
    }
  }

  void dispose() {
    _disposed = true;
    _pendingKeys.clear();
  }
}
