import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';

/// Persists series playback position while an episode is playing.
class SeriesResumeTracker extends ConsumerStatefulWidget {
  const SeriesResumeTracker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SeriesResumeTracker> createState() =>
      _SeriesResumeTrackerState();
}

class _SeriesResumeTrackerState extends ConsumerState<SeriesResumeTracker> {
  StreamSubscription<Duration>? _positionSub;
  Timer? _saveTimer;
  Duration _lastSavedPosition = Duration.zero;

  @override
  void dispose() {
    _flushPosition();
    _cancelSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SeriesActivePlayback?>(seriesActivePlaybackProvider, (
      previous,
      next,
    ) {
      _cancelSubscriptions();
      if (next == null) {
        if (previous != null) {
          _savePosition(previous, _lastSavedPosition);
        }
        return;
      }

      final player = ref.read(playerNotifierProvider).valueOrNull?.player;
      if (player == null) return;

      _lastSavedPosition = Duration.zero;
      _positionSub = player.stream.position.listen((position) {
        _lastSavedPosition = position;
      });

      _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        final active = ref.read(seriesActivePlaybackProvider);
        if (active != null) {
          _savePosition(active, _lastSavedPosition);
        }
      });
    });

    return widget.child;
  }

  void _flushPosition() {
    final active = ref.read(seriesActivePlaybackProvider);
    if (active != null) {
      _savePosition(active, _lastSavedPosition);
    }
  }

  void _cancelSubscriptions() {
    _positionSub?.cancel();
    _positionSub = null;
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  void _savePosition(SeriesActivePlayback playback, Duration position) {
    if (position.inMilliseconds <= 0) return;
    saveSeriesResume(
      ref,
      playback: playback,
      positionMs: position.inMilliseconds,
    );
  }
}
