import 'dart:async';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';

/// The server-side identity of one active Jellyfin playback session.
class JellyfinPlaybackSession {
  const JellyfinPlaybackSession({
    required this.itemId,
    required this.mediaSourceId,
    this.playSessionId,
    this.playMethod = 'DirectPlay',
  });

  final String itemId;
  final String mediaSourceId;
  final String? playSessionId;
  final String playMethod;
}

/// Sends Jellyfin session events without coupling HTTP failures to playback.
///
/// Progress is throttled by default to one request per ten seconds. Forced
/// updates are used for user-visible state changes such as pause/resume and
/// seek. Requests are serialized so start/progress/stop keep their order even
/// though callers intentionally do not await them on the playback path.
class JellyfinPlaybackReporter {
  JellyfinPlaybackReporter({
    required this._apiClient,
    DateTime Function()? now,
    this.progressInterval = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now;

  final JellyfinApiClient _apiClient;
  final DateTime Function() _now;
  final Duration progressInterval;

  Future<void> _queue = Future<void>.value();
  DateTime? _lastProgressAt;
  int? _lastProgressTicks;
  bool? _lastProgressPaused;

  Future<void> reportPlaybackStart({
    required JellyfinConnection connection,
    required JellyfinPlaybackSession session,
    Duration position = Duration.zero,
    bool isPaused = false,
  }) {
    final positionTicks = jellyfinDurationToTicks(position);
    _lastProgressAt = _now();
    _lastProgressTicks = positionTicks;
    _lastProgressPaused = isPaused;
    return _enqueue(
      () => _bestEffort(
        'start',
        () => _apiClient.reportPlaybackStart(
          connection,
          itemId: session.itemId,
          mediaSourceId: session.mediaSourceId,
          playSessionId: session.playSessionId,
          positionTicks: positionTicks,
          isPaused: isPaused,
          playMethod: session.playMethod,
        ),
      ),
    );
  }

  Future<void> reportPlaybackProgress({
    required JellyfinConnection connection,
    required JellyfinPlaybackSession session,
    required Duration position,
    required bool isPaused,
    bool force = false,
  }) {
    final positionTicks = jellyfinDurationToTicks(position);
    final now = _now();
    final isDuplicateForcedUpdate =
        force &&
        _lastProgressTicks == positionTicks &&
        _lastProgressPaused == isPaused;
    if (!force &&
        _lastProgressAt != null &&
        now.difference(_lastProgressAt!) < progressInterval) {
      return Future<void>.value();
    }
    if (isDuplicateForcedUpdate) return Future<void>.value();

    _lastProgressAt = now;
    _lastProgressTicks = positionTicks;
    _lastProgressPaused = isPaused;
    return _enqueue(
      () => _bestEffort(
        'progress',
        () => _apiClient.reportPlaybackProgress(
          connection,
          itemId: session.itemId,
          mediaSourceId: session.mediaSourceId,
          playSessionId: session.playSessionId,
          positionTicks: positionTicks,
          isPaused: isPaused,
          playMethod: session.playMethod,
        ),
      ),
    );
  }

  Future<void> reportPlaybackStopped({
    required JellyfinConnection connection,
    required JellyfinPlaybackSession session,
    required Duration position,
    required bool isPaused,
  }) {
    _lastProgressAt = null;
    _lastProgressTicks = null;
    _lastProgressPaused = null;
    return _enqueue(
      () => _bestEffort(
        'stopped',
        () => _apiClient.reportPlaybackStopped(
          connection,
          itemId: session.itemId,
          mediaSourceId: session.mediaSourceId,
          playSessionId: session.playSessionId,
          positionTicks: jellyfinDurationToTicks(position),
          isPaused: isPaused,
          playMethod: session.playMethod,
        ),
      ),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
  }

  Future<void> _bestEffort(
    String operation,
    Future<void> Function() request,
  ) async {
    try {
      await request();
    } on JellyfinApiException catch (error) {
      AppLogger.warning(
        'JellyfinPlaybackReporter: $operation failed (${error.kind.name}).',
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'JellyfinPlaybackReporter: $operation failed.',
        error,
        stackTrace,
      );
    }
  }
}

/// Converts Dart's microsecond duration to Jellyfin's 100-nanosecond ticks.
int jellyfinDurationToTicks(Duration position) {
  if (position.inMicroseconds <= 0) return 0;
  return position.inMicroseconds * 10;
}
