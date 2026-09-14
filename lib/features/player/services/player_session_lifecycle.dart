import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/player/services/player_event_bindings.dart';

/// Owns the native player resources attached to one [PlayerNotifier] lifetime.
///
/// Playback policy and Riverpod state stay in the notifier. This coordinator
/// only guarantees one event-binding set, one lazily-created video controller,
/// and idempotent asynchronous teardown.
final class PlayerSessionLifecycle<T> {
  final PlayerEventBindings _eventBindings = PlayerEventBindings();

  VideoController? _videoController;
  Future<T>? _initialization;
  Future<void>? _disposeFuture;
  int _sessionToken = 0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  Future<T>? get initialization => _initialization;

  Future<T> initializeOnce(Future<T> Function() initialize) {
    return _initialization ??= initialize();
  }

  int beginSession() {
    _sessionToken += 1;
    return _sessionToken;
  }

  bool isSessionCurrent(int token) => token == _sessionToken;

  VideoController videoControllerFor(Player player) {
    _videoController ??= VideoController(player);
    return _videoController!;
  }

  void invalidateVideoController() {
    _videoController = null;
  }

  void bind(
    Player player, {
    required void Function(bool value) onPlaying,
    required void Function(double value) onVolume,
    required void Function(bool value) onBuffering,
    required void Function(String value) onError,
    required void Function(Duration value) onPosition,
    required void Function(Duration value) onDuration,
    required void Function(Duration value) onBuffer,
    required void Function(Tracks value) onTracks,
    required void Function(dynamic value) onVideoParams,
    required void Function(dynamic value) onAudioParams,
    required void Function(double? value) onAudioBitrate,
  }) {
    _eventBindings.bind(
      player,
      onPlaying: onPlaying,
      onVolume: onVolume,
      onBuffering: onBuffering,
      onError: onError,
      onPosition: onPosition,
      onDuration: onDuration,
      onBuffer: onBuffer,
      onTracks: onTracks,
      onVideoParams: onVideoParams,
      onAudioParams: onAudioParams,
      onAudioBitrate: onAudioBitrate,
    );
  }

  Future<void> dispose(Player? player, {void Function()? onBegin}) {
    final existing = _disposeFuture;
    if (existing != null) return existing;

    onBegin?.call();
    final future = _dispose(player);
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose(Player? player) async {
    if (_isDisposed) return;
    _isDisposed = true;

    await _eventBindings.dispose();
    invalidateVideoController();

    if (player == null) return;
    try {
      await player.dispose();
    } catch (error, stackTrace) {
      AppLogger.error(
        'PlayerSessionLifecycle: Failed to dispose media_kit player',
        error,
        stackTrace,
      );
    }
  }
}
