import 'dart:async';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/playlist_epg.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/core/services/epg_sync_controller.dart';

typedef EpgTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Coordinates due automatic EPG refreshes without coupling scheduling to UI.
class EpgAutoRefreshCoordinator {
  EpgAutoRefreshCoordinator({
    required this.controller,
    required this.loadPlaylists,
    required this.loadInactivePlaylistIds,
    required this.loadInterval,
    EpgClock? now,
    EpgTimerFactory? timerFactory,
  }) : _now = now ?? DateTime.now,
       _timerFactory = timerFactory ?? Timer.new;

  final EpgSyncController controller;
  final Future<List<Playlist>> Function() loadPlaylists;
  final Future<Set<int>> Function() loadInactivePlaylistIds;
  final Future<EpgRefreshInterval> Function(int playlistId) loadInterval;
  final EpgClock _now;
  final EpgTimerFactory _timerFactory;

  final Map<int, int> _failureCounts = <int, int>{};
  final Map<int, DateTime> _retryAt = <int, DateTime>{};
  StreamSubscription<EpgSyncJob>? _eventsSubscription;
  Timer? _timer;
  Future<void>? _checkFuture;
  DateTime? _nextScheduledAt;
  bool _started = false;
  bool _disposed = false;

  DateTime? get nextScheduledAt => _nextScheduledAt;

  DateTime? retryAtFor(int playlistId) => _retryAt[playlistId];

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _eventsSubscription = controller.watchEvents().listen(_onJobEvent);
    unawaited(checkNow());
  }

  Future<void> onResume() {
    start();
    return checkNow();
  }

  Future<void> refreshNow() {
    start();
    return checkNow();
  }

  Future<void> checkNow() {
    if (_disposed) return Future<void>.value();
    return _checkFuture ??= _checkNow();
  }

  Future<void> _checkNow() async {
    try {
      final playlists = await loadPlaylists();
      final inactiveIds = await loadInactivePlaylistIds();
      final now = _now();
      DateTime? nextWake;

      for (final playlist in playlists) {
        final interval = await loadInterval(playlist.id);
        final epgUrl = playlist.effectiveEpgUrl;
        if (inactiveIds.contains(playlist.id) ||
            epgUrl == null ||
            epgUrl.isEmpty ||
            !interval.isAutomatic) {
          continue;
        }

        final retryAt = _retryAt[playlist.id];
        if (retryAt != null && now.isBefore(retryAt)) {
          nextWake = _earlier(nextWake, retryAt);
          continue;
        }

        final job = controller.jobFor(playlist.id);
        if (job?.isActive == true) continue;

        final lastSuccess = playlist.epgLastSyncedAt;
        final dueAt =
            lastSuccess?.add(interval.duration!) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (!now.isBefore(dueAt)) {
          unawaited(
            controller
                .enqueue(playlist.id, origin: EpgSyncOrigin.automatic)
                .catchError((_) {}),
          );
          continue;
        }
        nextWake = _earlier(nextWake, dueAt);
      }

      _schedule(nextWake, now);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'EpgAutoRefreshCoordinator: Automatic refresh check failed: $error',
      );
      AppLogger.debug(stackTrace.toString());
      _schedule(_now().add(const Duration(minutes: 15)), _now());
    } finally {
      _checkFuture = null;
    }
  }

  void _onJobEvent(EpgSyncJob job) {
    if (!job.isComplete) return;
    if (job.origin == EpgSyncOrigin.automatic) {
      if (job.status == EpgSyncStatus.succeeded) {
        _failureCounts.remove(job.playlistId);
        _retryAt.remove(job.playlistId);
      } else if (job.status == EpgSyncStatus.failed) {
        final count = (_failureCounts[job.playlistId] ?? 0) + 1;
        _failureCounts[job.playlistId] = count;
        final minutes = (15 * (1 << (count - 1))).clamp(15, 60);
        _retryAt[job.playlistId] = _now().add(
          Duration(minutes: minutes.toInt()),
        );
      }
    } else if (job.status == EpgSyncStatus.succeeded) {
      _failureCounts.remove(job.playlistId);
      _retryAt.remove(job.playlistId);
    }
    unawaited(checkNow());
  }

  void _schedule(DateTime? next, DateTime now) {
    _timer?.cancel();
    _timer = null;
    _nextScheduledAt = next;
    if (_disposed || next == null) return;
    final delay = next.difference(now);
    _timer = _timerFactory(
      delay.isNegative || delay == Duration.zero
          ? const Duration(milliseconds: 1)
          : delay,
      () => unawaited(checkNow()),
    );
  }

  DateTime _earlier(DateTime? current, DateTime candidate) {
    if (current == null || candidate.isBefore(current)) return candidate;
    return current;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
  }
}
