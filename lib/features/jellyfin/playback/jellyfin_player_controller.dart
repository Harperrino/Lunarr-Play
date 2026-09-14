import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_info.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_device_profile.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_native_subtitle_selection.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_reporter.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_log_redactor.dart';

/// Optional host hook called before a Jellyfin video starts (stops an
/// existing Lunarr/Xtream stream). No-op by default.
typedef JellyfinExistingPlaybackStopper = Future<void> Function();
typedef JellyfinPlayerFactory = Player Function();
typedef JellyfinVideoControllerFactory = VideoController Function(Player);

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
    this.maxStreamingBitrate,
    this._stopExistingPlayback,
    this._playbackReporter,
    this._onPlaybackStopped,
    Player? player,
    JellyfinPlayerFactory? playerFactory,
    JellyfinVideoControllerFactory? videoControllerFactory,
    Duration playerOpenTimeout = const Duration(seconds: 10),
    Duration nativeSubtitleTrackWait = const Duration(milliseconds: 250),
  }) {
    _playerFactory = playerFactory ?? Player.new;
    _videoControllerFactory = videoControllerFactory ?? VideoController.new;
    _playerOpenTimeout = playerOpenTimeout;
    _nativeSubtitleTrackWait = nativeSubtitleTrackWait;
    _installPlayer(player ?? _playerFactory());
  }

  final JellyfinConnection _connection;
  final JellyfinApiClient _apiClient;
  final JellyfinDeviceProfile _deviceProfile;
  final int? maxStreamingBitrate;
  final JellyfinExistingPlaybackStopper? _stopExistingPlayback;
  final JellyfinPlaybackReporter? _playbackReporter;
  final VoidCallback? _onPlaybackStopped;
  final JellyfinLogRedactor _redactor = const JellyfinLogRedactor();
  final JellyfinPlaybackResolver _resolver = const JellyfinPlaybackResolver();
  late final JellyfinPlayerFactory _playerFactory;
  late final JellyfinVideoControllerFactory _videoControllerFactory;
  late final Duration _playerOpenTimeout;
  late final Duration _nativeSubtitleTrackWait;

  late Player _player;
  late VideoController _videoController;
  int _playerGeneration = -1;

  final ValueNotifier<JellyfinPlayerState> state =
      ValueNotifier<JellyfinPlayerState>(const JellyfinPlayerState());

  final List<StreamSubscription<Object?>> _subscriptions = [];
  double _lastVolume = 1.0;
  bool _disposed = false;
  int _playAttempt = 0;
  JellyfinPlaybackSession? _activeSession;
  JellyfinItem? _currentItem;
  Future<void> _playerLifecycleQueue = Future<void>.value();
  Future<void>? _disposeFuture;
  int _queuedStops = 0;

  Player get player => _player;
  VideoController get videoController => _videoController;

  void _installPlayer(Player player) {
    _player = player;
    _videoController = _videoControllerFactory(player);
    _playerGeneration++;
    if (_playerGeneration > 0) {
      _mutate((s) => s.copyWith(playerGeneration: _playerGeneration));
    }
    _bindPlayerStreams(player, _playerGeneration);
  }

  void _bindPlayerStreams(Player player, int generation) {
    bool active() =>
        !_disposed &&
        generation == _playerGeneration &&
        identical(player, _player);
    _subscriptions.add(
      player.stream.playing.listen((value) {
        if (!active()) return;
        final changed = state.value.playing != value;
        _mutate((s) => s.copyWith(playing: value));
        if (changed) {
          _reportPlaybackProgress(force: true, isPaused: !value);
        }
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((value) {
        if (active()) _mutate((s) => s.copyWith(buffering: value));
      }),
    );
    _subscriptions.add(
      player.stream.completed.listen((value) {
        if (!active()) return;
        _mutate((s) => s.copyWith(completed: value));
        if (value) _reportPlaybackStopped();
      }),
    );
    _subscriptions.add(
      player.stream.volume.listen((value) {
        if (!active()) return;
        final normalized = (value / 100.0).clamp(0.0, 1.0).toDouble();
        _mutate((s) => s.copyWith(volume: normalized, muted: normalized <= 0));
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((value) {
        if (active()) _mutate((s) => s.copyWith(duration: value));
      }),
    );
    _subscriptions.add(
      player.stream.position.listen((value) {
        if (!active()) return;
        // Position ticks flood; only republish whole-second changes.
        if ((value - state.value.position).inSeconds.abs() >= 1) {
          _mutate((s) => s.copyWith(position: value));
          _reportPlaybackProgress();
        }
      }),
    );
    _subscriptions.add(
      player.stream.error.listen((message) {
        if (!active()) return;
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

  /// Resolves and opens [item] using Jellyfin's Direct Play, Direct Stream,
  /// or Transcoding decision and starts playback.
  Future<void> play(
    JellyfinItem item, {
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) {
    return _startPlayback(
      item,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      startTimeTicks: item.playbackPositionTicks,
      stopHostPlayback: true,
      switchingTrack: false,
      resetSelections: true,
    );
  }

  /// Re-resolves PlaybackInfo so Jellyfin can select a new audio stream.
  Future<void> selectAudioTrack(int streamIndex) async {
    if (_disposed || !_canChangeTrack || streamIndex < 0) return;
    await _reopenWithTracks(audioStreamIndex: streamIndex);
  }

  /// Re-resolves PlaybackInfo so Jellyfin can select a new subtitle stream.
  /// A null index means subtitles off and is sent as `-1` to Jellyfin.
  Future<void> selectSubtitleTrack(int? streamIndex) async {
    if (_disposed || !_canChangeTrack) return;
    await _reopenWithTracks(subtitleStreamIndex: streamIndex ?? -1);
  }

  Future<void> _reopenWithTracks({
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    final item = _currentItem;
    if (item == null || !_canChangeTrack) return;
    final currentAudio =
        audioStreamIndex ?? state.value.selectedAudioStreamIndex;
    final currentSubtitle =
        subtitleStreamIndex ?? state.value.selectedSubtitleStreamIndex;
    final startTimeTicks = jellyfinDurationToTicks(state.value.position);
    _mutate((s) => s.copyWith(switchingTrack: true));
    await _startPlayback(
      item,
      audioStreamIndex: currentAudio >= 0 ? currentAudio : null,
      subtitleStreamIndex: currentSubtitle,
      startTimeTicks: startTimeTicks,
      stopHostPlayback: false,
      switchingTrack: true,
      resetSelections: false,
    );
  }

  Future<void> _startPlayback(
    JellyfinItem item, {
    required int? audioStreamIndex,
    required int? subtitleStreamIndex,
    required int startTimeTicks,
    required bool stopHostPlayback,
    required bool switchingTrack,
    required bool resetSelections,
  }) async {
    if (_disposed) return;
    final previousState = state.value;
    final previousMediaSourceId = previousState.mediaSourceId;
    final previousAudioTracks = previousState.audioTracks;
    final previousSubtitleTracks = previousState.subtitleTracks;
    _currentItem = item;
    final attempt = ++_playAttempt;
    _reportPlaybackStopped();
    _mutate(
      (s) => s.copyWith(
        title: item.name,
        error: false,
        completed: false,
        position: Duration.zero,
        duration: Duration.zero,
        initialized: false,
        clearMethod: true,
        clearMediaSourceId: true,
        audioTracks: resetSelections ? const [] : s.audioTracks,
        subtitleTracks: resetSelections ? const [] : s.subtitleTracks,
        selectedAudioStreamIndex: resetSelections
            ? -1
            : s.selectedAudioStreamIndex,
        selectedSubtitleStreamIndex: resetSelections
            ? -1
            : s.selectedSubtitleStreamIndex,
        switchingTrack: switchingTrack,
      ),
    );

    try {
      if (stopHostPlayback && _stopExistingPlayback != null) {
        await _stopExistingPlayback();
      } else if (!stopHostPlayback) {
        await _enqueuePlayerStop();
      }
      if (!_isCurrentAttempt(attempt)) return;

      var playbackInfo = await _apiClient.fetchPlaybackInfo(
        _connection,
        itemId: item.id,
        deviceProfile: _deviceProfile,
        startTimeTicks: startTimeTicks,
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
        enableDirectPlay: true,
        enableDirectStream: false,
        enableTranscoding: false,
        maxStreamingBitrate: maxStreamingBitrate,
      );
      if (!_isCurrentAttempt(attempt)) return;
      JellyfinResolvedPlayback resolved;
      try {
        resolved = _resolver.resolve(
          baseUrl: _connection.baseUrl,
          accessToken: _connection.accessToken,
          item: item,
          playbackInfo: playbackInfo,
          startTimeTicks: startTimeTicks,
          audioStreamIndex: audioStreamIndex,
          subtitleStreamIndex: subtitleStreamIndex,
        );
        if (resolved.method != JellyfinPlaybackMethod.directPlay) {
          throw const JellyfinPlaybackResolutionException(
            'The direct-play-only request did not return a Direct Play URL.',
          );
        }
      } on JellyfinPlaybackResolutionException {
        // Ask for remux/transcoding only after the server explicitly rejected
        // the complete Direct Play profile.
        playbackInfo = await _apiClient.fetchPlaybackInfo(
          _connection,
          itemId: item.id,
          deviceProfile: _deviceProfile,
          startTimeTicks: startTimeTicks,
          audioStreamIndex: audioStreamIndex,
          subtitleStreamIndex: subtitleStreamIndex,
          enableDirectPlay: true,
          enableDirectStream: true,
          enableTranscoding: true,
          maxStreamingBitrate: maxStreamingBitrate,
        );
        if (!_isCurrentAttempt(attempt)) return;
        resolved = _resolver.resolve(
          baseUrl: _connection.baseUrl,
          accessToken: _connection.accessToken,
          item: item,
          playbackInfo: playbackInfo,
          startTimeTicks: startTimeTicks,
          audioStreamIndex: audioStreamIndex,
          subtitleStreamIndex: subtitleStreamIndex,
        );
      }
      if (!_isCurrentAttempt(attempt)) return;

      final selectedStreams = resolved.mediaSource.mediaStreams.isNotEmpty
          ? resolved.mediaSource.mediaStreams
          : playbackInfo.mediaStreams;
      final resolvedAudioTracks = selectedStreams
          .where((stream) => stream.type == JellyfinMediaStreamType.audio)
          .toList(growable: false);
      final resolvedSubtitleTracks = selectedStreams
          .where((stream) => stream.type == JellyfinMediaStreamType.subtitle)
          .toList(growable: false);
      final sameMediaSource =
          !resetSelections &&
          previousMediaSourceId != null &&
          previousMediaSourceId == resolved.mediaSourceId;
      final audioTracks = sameMediaSource && resolvedAudioTracks.isEmpty
          ? previousAudioTracks
          : resolvedAudioTracks;
      final subtitleTracks = sameMediaSource && resolvedSubtitleTracks.isEmpty
          ? previousSubtitleTracks
          : resolvedSubtitleTracks;
      final selectedAudio = _validStreamIndex(
        audioStreamIndex ??
            resolved.mediaSource.defaultAudioStreamIndex ??
            playbackInfo.defaultAudioStreamIndex,
        audioTracks,
        selectFirst: true,
      );
      final selectedSubtitle = _validStreamIndex(
        subtitleStreamIndex ??
            resolved.mediaSource.defaultSubtitleStreamIndex ??
            playbackInfo.defaultSubtitleStreamIndex,
        subtitleTracks,
        selectFirst: false,
        allowOff: true,
      );
      _mutate(
        (s) => s.copyWith(
          audioTracks: audioTracks,
          subtitleTracks: subtitleTracks,
          selectedAudioStreamIndex: selectedAudio,
          selectedSubtitleStreamIndex: selectedSubtitle,
        ),
      );

      AppLogger.info(
        _redactor.redact(
          'JellyfinPlayerController: Opening ${resolved.method.name} '
          'stream for ${item.name} (${item.id}).',
        ),
      );

      await _openForAttempt(
        attempt,
        Media(
          resolved.uri,
          httpHeaders: resolved.headers,
          start: resolved.startPosition,
        ),
        disableSubtitles: selectedSubtitle < 0,
        selectedSubtitleStream: subtitleTracks
            .where((track) => track.index == selectedSubtitle)
            .firstOrNull,
        subtitleTracks: subtitleTracks,
        playbackMethod: resolved.method,
      );
      if (!_isCurrentAttempt(attempt)) return;

      final session = JellyfinPlaybackSession(
        itemId: item.id,
        mediaSourceId: resolved.mediaSourceId,
        playSessionId: resolved.playSessionId,
        playMethod: _playMethod(resolved.method),
      );
      _activeSession = session;
      _mutate(
        (s) => s.copyWith(
          initialized: true,
          method: resolved.method,
          mediaSourceId: resolved.mediaSourceId,
          switchingTrack: false,
        ),
      );
      final reporter = _playbackReporter;
      if (reporter != null) {
        unawaited(
          reporter.reportPlaybackStart(
            connection: _connection,
            session: session,
            position: resolved.startPosition,
          ),
        );
      }
    } on JellyfinApiException catch (error) {
      if (!_isCurrentAttempt(attempt)) return;
      AppLogger.warning(
        'JellyfinPlayerController: PlaybackInfo failed '
        '(${error.kind.name}).',
      );
      _mutate((s) => s.copyWith(error: true, switchingTrack: false));
    } on JellyfinPlaybackResolutionException catch (error) {
      if (!_isCurrentAttempt(attempt)) return;
      AppLogger.warning('JellyfinPlayerController: ${error.message}');
      _mutate((s) => s.copyWith(error: true, switchingTrack: false));
    } catch (error, stackTrace) {
      if (!_isCurrentAttempt(attempt)) return;
      AppLogger.error(
        'JellyfinPlayerController: Playback failed to start.',
        error,
        stackTrace,
      );
      _mutate((s) => s.copyWith(error: true, switchingTrack: false));
    }
  }

  Future<void> togglePlayPause() async {
    if (_disposed || !state.value.initialized || state.value.error) return;
    final wasPlaying = state.value.playing;
    await _player.playOrPause();
    if (_disposed) return;
    _reportPlaybackProgress(force: true, isPaused: wasPlaying);
  }

  Future<void> seek(Duration position) async {
    if (_disposed || !state.value.initialized) return;
    final target = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _maxSeekMs),
    );
    await _player.seek(target);
    if (_disposed) return;
    _mutate((s) => s.copyWith(position: target));
    _reportPlaybackProgress(force: true);
  }

  Future<void> seekRelative(Duration delta) async {
    final current = state.value.position;
    await seek(current + delta);
  }

  Future<void> setVolume(double volume) async {
    if (_disposed) return;
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    if (clamped > 0) _lastVolume = clamped;
    await _player.setVolume(clamped * 100.0);
    _mutate((s) => s.copyWith(volume: clamped, muted: clamped <= 0));
  }

  Future<void> toggleMute() async {
    if (_disposed) return;
    final muted = !state.value.muted;
    final target = muted ? 0.0 : (_lastVolume > 0 ? _lastVolume : 1.0);
    await _player.setVolume(target * 100.0);
    _mutate((s) => s.copyWith(muted: muted, volume: target));
  }

  /// Stops playback but keeps the instance alive (e.g. while staying on the
  /// playback screen).
  Future<void> stop() async {
    if (_disposed) return;
    ++_playAttempt;
    _reportPlaybackStopped();
    await _enqueuePlayerStop();
    _mutate(
      (s) => s.copyWith(
        playing: false,
        buffering: false,
        completed: false,
        position: Duration.zero,
        initialized: false,
        clearMediaSourceId: true,
      ),
    );
  }

  /// Full deterministic teardown: stop, then dispose the player. The video
  /// controller is released by `Player.dispose()` (media_kit ownership
  /// contract). Idempotent.
  Future<void> disposeAsync() async {
    final existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }

    final future = _disposeInternal();
    _disposeFuture = future;
    return future;
  }

  Future<void> _disposeInternal() async {
    if (_disposed) return;
    ++_playAttempt;
    _reportPlaybackStopped();
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    await _enqueueLifecycleOperation(() async {
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
    });
    state.dispose();
  }

  bool _isCurrentAttempt(int attempt) => !_disposed && attempt == _playAttempt;

  Future<void> _openForAttempt(
    int attempt,
    Media media, {
    required bool disableSubtitles,
    required JellyfinMediaStream? selectedSubtitleStream,
    required List<JellyfinMediaStream> subtitleTracks,
    required JellyfinPlaybackMethod playbackMethod,
  }) {
    return _enqueueLifecycleOperation(() async {
      if (!_isCurrentAttempt(attempt)) return;
      final openingPlayer = _player;
      final generation = _playerGeneration;
      final openFuture = openingPlayer.open(media, play: false);
      try {
        await openFuture.timeout(_playerOpenTimeout);
      } on TimeoutException {
        AppLogger.warning(
          'JellyfinPlayerController: Player open timed out after '
          '${_playerOpenTimeout.inSeconds}s.',
        );
        await _retireTimedOutPlayer(openingPlayer, generation, openFuture);
        rethrow;
      }
      if (!_isCurrentAttempt(attempt) ||
          generation != _playerGeneration ||
          !identical(openingPlayer, _player)) {
        if (!_disposed && _queuedStops == 0) await openingPlayer.stop();
        return;
      }
      if (disableSubtitles) {
        await openingPlayer.setSubtitleTrack(SubtitleTrack.no());
        if (!_isCurrentAttempt(attempt) ||
            generation != _playerGeneration ||
            !identical(openingPlayer, _player)) {
          if (!_disposed && _queuedStops == 0) await openingPlayer.stop();
          return;
        }
      } else if (playbackMethod == JellyfinPlaybackMethod.directPlay &&
          selectedSubtitleStream != null) {
        final nativeTrack = await _nativeSubtitleTrack(
          openingPlayer,
          selectedSubtitleStream.index,
          subtitleTracks,
        );
        if (!_isCurrentAttempt(attempt) ||
            generation != _playerGeneration ||
            !identical(openingPlayer, _player)) {
          if (!_disposed && _queuedStops == 0) await openingPlayer.stop();
          return;
        }
        if (nativeTrack != null) {
          await openingPlayer.setSubtitleTrack(nativeTrack);
          if (!_isCurrentAttempt(attempt) ||
              generation != _playerGeneration ||
              !identical(openingPlayer, _player)) {
            if (!_disposed && _queuedStops == 0) await openingPlayer.stop();
            return;
          }
        }
      }
      await openingPlayer.play();
    });
  }

  Future<SubtitleTrack?> _nativeSubtitleTrack(
    Player player,
    int selectedStreamIndex,
    List<JellyfinMediaStream> subtitleTracks,
  ) async {
    SubtitleTrack? match(Tracks tracks) => jellyfinNativeSubtitleTrackFor(
      selectedStreamIndex: selectedStreamIndex,
      jellyfinTracks: subtitleTracks,
      nativeTracks: tracks.subtitle,
    );

    final immediate = match(player.state.tracks);
    if (immediate != null || _nativeSubtitleTrackWait <= Duration.zero) {
      return immediate;
    }
    try {
      final tracks = await player.stream.tracks
          .firstWhere((tracks) => match(tracks) != null)
          .timeout(_nativeSubtitleTrackWait);
      return match(tracks);
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _retireTimedOutPlayer(
    Player timedOutPlayer,
    int generation,
    Future<void> openFuture,
  ) async {
    if (generation != _playerGeneration ||
        !identical(timedOutPlayer, _player)) {
      return;
    }
    if (_disposed) {
      unawaited(_disposeRetiredPlayer(timedOutPlayer, openFuture));
      return;
    }
    final staleSubscriptions = List<StreamSubscription<Object?>>.of(
      _subscriptions,
    );
    _subscriptions.clear();
    for (final subscription in staleSubscriptions) {
      await subscription.cancel();
    }
    _installPlayer(_playerFactory());
    unawaited(_disposeRetiredPlayer(timedOutPlayer, openFuture));
  }

  Future<void> _disposeRetiredPlayer(
    Player retiredPlayer,
    Future<void> openFuture,
  ) async {
    try {
      await openFuture;
    } catch (_) {
      // The open failure is already surfaced by the active playback attempt.
    }
    try {
      await retiredPlayer.stop();
    } catch (_) {}
    try {
      await retiredPlayer.dispose();
    } catch (_) {}
  }

  Future<void> _enqueuePlayerStop() {
    ++_queuedStops;
    return _enqueueLifecycleOperation(() async {
      try {
        await _player.stop();
      } finally {
        --_queuedStops;
      }
    });
  }

  Future<void> _enqueueLifecycleOperation(Future<void> Function() operation) {
    final result = _playerLifecycleQueue.then((_) => operation());
    _playerLifecycleQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  void _reportPlaybackProgress({bool force = false, bool? isPaused}) {
    final session = _activeSession;
    final reporter = _playbackReporter;
    if (session == null || reporter == null || _disposed) return;
    unawaited(
      reporter.reportPlaybackProgress(
        connection: _connection,
        session: session,
        position: state.value.position,
        isPaused: isPaused ?? !state.value.playing,
        force: force,
      ),
    );
  }

  void _reportPlaybackStopped() {
    final session = _activeSession;
    if (session == null) return;
    _activeSession = null;
    final reporter = _playbackReporter;
    if (reporter != null) {
      unawaited(
        reporter.reportPlaybackStopped(
          connection: _connection,
          session: session,
          position: state.value.position,
          isPaused: !state.value.playing,
        ),
      );
    }
    _onPlaybackStopped?.call();
  }

  int get _maxSeekMs {
    final durationMs = state.value.duration.inMilliseconds;
    return durationMs > 0 ? durationMs : 1 << 31;
  }

  bool get _canChangeTrack =>
      state.value.initialized && !state.value.error && _currentItem != null;

  int _defaultStreamIndex(
    List<JellyfinMediaStream> streams, {
    required bool selectFirst,
  }) {
    for (final stream in streams) {
      if (stream.isDefault) return stream.index;
    }
    return selectFirst && streams.isNotEmpty ? streams.first.index : -1;
  }

  int _validStreamIndex(
    int? requested,
    List<JellyfinMediaStream> streams, {
    required bool selectFirst,
    bool allowOff = false,
  }) {
    if (allowOff && requested != null && requested < 0) return -1;
    if (requested != null &&
        streams.any((stream) => stream.index == requested)) {
      return requested;
    }
    return _defaultStreamIndex(streams, selectFirst: selectFirst);
  }

  String _playMethod(JellyfinPlaybackMethod method) => switch (method) {
    JellyfinPlaybackMethod.directPlay => 'DirectPlay',
    JellyfinPlaybackMethod.directStream => 'DirectStream',
    JellyfinPlaybackMethod.transcode => 'Transcode',
  };
}
