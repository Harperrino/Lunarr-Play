import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const bool tabTransitionProbeOptIn = bool.fromEnvironment(
  'TAB_TRANSITION_PERF',
);

@immutable
class TabTransitionSample {
  const TabTransitionSample({
    required this.fromIndex,
    required this.toIndex,
    required this.warm,
    required this.firstRasterFrame,
    required this.firstContentFrame,
    required this.buildDuration,
    required this.rasterDuration,
    required this.requestCount,
    required this.rssDeltaBytes,
  });

  final int fromIndex;
  final int toIndex;
  final bool warm;
  final Duration? firstRasterFrame;
  final Duration firstContentFrame;
  final Duration? buildDuration;
  final Duration? rasterDuration;
  final int requestCount;
  final int rssDeltaBytes;
}

/// Opt-in/profile instrumentation for sidebar transition acceptance runs.
class TabTransitionProbe {
  TabTransitionProbe({bool? enabled, int Function()? currentRss})
    : enabled = enabled ?? (kProfileMode || tabTransitionProbeOptIn),
      _currentRss = currentRss ?? (() => ProcessInfo.currentRss) {
    if (this.enabled) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }
  }

  final bool enabled;
  final int Function() _currentRss;
  final Set<int> _visitedTargets = <int>{};
  final List<TabTransitionSample> _samples = <TabTransitionSample>[];
  final StreamController<TabTransitionSample> _events =
      StreamController<TabTransitionSample>.broadcast(sync: true);
  _PendingTabTransition? _pending;

  List<TabTransitionSample> get samples => List.unmodifiable(_samples);
  Stream<TabTransitionSample> get events => _events.stream;

  void begin({required int fromIndex, required int toIndex}) {
    if (!enabled || fromIndex == toIndex) return;
    final pending = _PendingTabTransition(
      fromIndex: fromIndex,
      toIndex: toIndex,
      warm: !_visitedTargets.add(toIndex),
      stopwatch: Stopwatch()..start(),
      rssAtStart: _currentRss(),
    );
    _pending = pending;
    unawaited(
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (identical(_pending, pending)) {
          pending.firstRasterFrame ??= pending.stopwatch.elapsed;
        }
      }),
    );
  }

  /// Counts one async provider load initiated while the transition is active.
  void recordRequest() {
    if (enabled) _pending?.requestCount++;
  }

  void markContentMounted(int index) {
    final pending = _pending;
    if (!enabled || pending == null || pending.toIndex != index) return;
    unawaited(
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (!identical(_pending, pending)) return;
        pending.stopwatch.stop();
        final timing = pending.frameTiming;
        final sample = TabTransitionSample(
          fromIndex: pending.fromIndex,
          toIndex: pending.toIndex,
          warm: pending.warm,
          firstRasterFrame: pending.firstRasterFrame,
          firstContentFrame: pending.stopwatch.elapsed,
          buildDuration: timing?.buildDuration,
          rasterDuration: timing?.rasterDuration,
          requestCount: pending.requestCount,
          rssDeltaBytes: _currentRss() - pending.rssAtStart,
        );
        _pending = null;
        _samples.add(sample);
        if (_samples.length > 100) _samples.removeAt(0);
        if (!_events.isClosed) _events.add(sample);
      }),
    );
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    final pending = _pending;
    if (pending == null || pending.frameTiming != null || timings.isEmpty) {
      return;
    }
    pending.frameTiming = timings.first;
  }

  void dispose() {
    if (enabled) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
    _pending = null;
    unawaited(_events.close());
  }
}

class _PendingTabTransition {
  _PendingTabTransition({
    required this.fromIndex,
    required this.toIndex,
    required this.warm,
    required this.stopwatch,
    required this.rssAtStart,
  });

  final int fromIndex;
  final int toIndex;
  final bool warm;
  final Stopwatch stopwatch;
  final int rssAtStart;
  FrameTiming? frameTiming;
  Duration? firstRasterFrame;
  int requestCount = 0;
}
