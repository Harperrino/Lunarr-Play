import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_device_profile.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_log_redactor.dart';

/// Optional host hook called before a Jellyfin video starts (stops an
/// existing Lunarr/Xtream stream). No-op by default.
typedef JellyfinExistingPlaybackStopper = Future<void> Function();

/// Owns the Jellyfin media_kit instance — Player B.
///
/// The instance is exclusively owned by this controller: no
/// `PlayerNotifier`, no `selectedChannelProvider`, no shared lifecycle.
/// Dispose is deterministic and idempotent; the autoDispose provider calls it
/// when the playback screen (or the Jellyfin tab) goes away.
class JellyfinPlayerController {
  JellyfinPlayerController({
    required this._connection,
    required this._apiClient,
    this._deviceProfile = const JellyfinDeviceProfile(),
    this._stopExistingPlayback,
    Player? player,
    VideoController Function(Player player)? videoControllerFactory,
  }) {
    _player = player ?? Player();
    _videoController = (videoControllerFactory ?? VideoController.new)(
      _player,
    );
    _bindPlayerStreams();
  }

  final JellyfinConnection _connection;
  final JellyfinApiClient _apiClient;
  final JellyfinDeviceProfile _deviceProfile;
  final JellyfinExistingPlaybackStopper? _stopExistingPlayback;
  final JellyfinLogRedactor _redactor = const JellyfinLogRedactor();
  final JellyfinPlaybackResolver _resolver = const JellyfinPlaybackResolver();

  late final Player _player;
  late final VideoController _videoController;

  final ValueNotifier<JellyfinPlayerState> state =
      ValueNotifier<JellyfinPlayerState>(const JellyfinPlayerState());

  final List<StreamSubscription<Object?>> _subscriptions = [];
  double _lastVolume = 1.0;
  bool _disposed = false;

  Player get player => _player;
  VideoController get videoController => _videoController;

  void _bindPlayerStreams() {
    _subscriptions.add(
      _player.stream.playing.listen(
        (value) => _mutate((s) => s.copyWith(playing: value)),
      ),
    );
    _subscriptions.add(
      _player.stream.buffering.listen(
        (value) => _mutate((s) => s.copyWith(buffering: value)),
      ),
    );
    _subscriptions.add(
      _player.stream.completed.listen(
        (value) => _mutate((s) => s.copyWith(completed: value)),
      ),
    );
    _subscriptions.add(
      _player.stream.volume.listen(
        (value) => _mutate((s) => s.copyWith(volume: value)),
      ),
    );
    _subscriptions.add(
      _player.stream.duration.listen(
        (value) => _mutate((s) => s.copyWith(duration: value)),
      ),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        // Position ticks flood; only republish whole-second changes.
        if ((value - state.value.position).inSeconds.abs() >= 1) {
          _mutate((s) => s.copyWith(position: value));
        }
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((message) {
        if (message.isEmpty) return;
        AppLogger.warning(
          _redactor.redact('JellyfinPlayerController: Player error: $message'),
        );
        _mutate((s) => s.copyWith(error: true));
      }),
    );
  }

  void _mutate(JellyfinPlayerState Function(JellyfinPlayerState) update) {
    if (_disposed) return;
    state.value = update(state.value);
  }

  /// Resolves and opens [item] for Direct Play and starts playback.
  Future<void> play(JellyfinItem item) async {
    if (_disposed) return;
    _mutate(
      (s) => s.copyWith(
        title: item.name,
        error: false,
        completed: false,
        position: Duration.zero,
        duration: Duration.zero,
        initialized: false,
      ),
    );

    try {
      if (_stopExistingPlayback != null) {
        await _stopExistingPlayback();
      }

      final playbackInfo = await _apiClient.fetchPlaybackInfo(
        _connection,
        itemId: item.id,
        deviceProfile: _deviceProfile,
        startTimeTicks: item.playbackPositionTicks,
      );
      final resolved = _resolver.resolve(
        baseUrl: _connection.baseUrl,
        accessToken: _connection.accessToken,
        item: item,
        playbackInfo: playbackInfo,
      );

      AppLogger.info(
        _redactor.redact(
          'JellyfinPlayerController: Opening ${resolved.method.name} '
          'stream for ${item.name} (${item.id}).',
        ),
      );

      await _player.open(
        Media(
          resolved.uri,
          httpHeaders: resolved.headers,
          start: resolved.startPosition,
        ),
      );
      _mutate(
        (s) => s.copyWith(initialized: true, method: resolved.method),
      );
    } on JellyfinApiException catch (error) {
      AppLogger.warning(
        'JellyfinPlayerController: PlaybackInfo failed '
        '(${error.kind.name}).',
      );
      _mutate((s) => s.copyWith(error: true));
    } on JellyfinPlaybackResolutionException catch (error) {
      AppLogger.warning(
        'JellyfinPlayerController: ${error.message}',
      );
      _mutate((s) => s.copyWith(error: true));
    } catch (error, stackTrace) {
      AppLogger.error(
        'JellyfinPlayerController: Playback failed to start.',
        error,
        stackTrace,
      );
      _mutate((s) => s.copyWith(error: true));
    }
  }

  Future<void> togglePlayPause() async {
    if (_disposed || !state.value.initialized || state.value.error) return;
    await _player.playOrPause();
  }

  Future<void> seek(Duration position) async {
    if (_disposed || !state.value.initialized) return;
    final target = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _maxSeekMs),
    );
    await _player.seek(target);
    _mutate((s) => s.copyWith(position: target));
  }

  Future<void> seekRelative(Duration delta) async {
    final current = state.value.position;
    await seek(current + delta);
  }

  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped > 0) _lastVolume = clamped;
    await _player.setVolume(clamped);
    _mutate((s) => s.copyWith(volume: clamped));
  }

  Future<void> toggleMute() async {
    if (_disposed) return;
    final muted = !state.value.muted;
    final target = muted ? 0.0 : (_lastVolume > 0 ? _lastVolume : 1.0);
    await _player.setVolume(target);
    _mutate((s) => s.copyWith(muted: muted, volume: target));
  }

  /// Stops playback but keeps the instance alive (e.g. while staying on the
  /// playback screen).
  Future<void> stop() async {
    if (_disposed) return;
    await _player.stop();
    _mutate(
      (s) => s.copyWith(
        playing: false,
        buffering: false,
        completed: false,
        position: Duration.zero,
        initialized: false,
      ),
    );
  }

  /// Full deterministic teardown: stop, then dispose the player. The video
  /// controller is released by `Player.dispose()` (media_kit ownership
  /// contract). Idempotent.
  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    try {
      await _player.stop();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'JellyfinPlayerController: Player stop during dispose failed.',
        error,
        stackTrace,
      );
    }
    try {
      await _player.dispose();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'JellyfinPlayerController: Player dispose failed.',
        error,
        stackTrace,
      );
    }
    state.dispose();
  }

  int get _maxSeekMs {
    final durationMs = state.value.duration.inMilliseconds;
    return durationMs > 0 ? durationMs : 1 << 31;
  }
}
