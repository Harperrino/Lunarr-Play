import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/media_kit_video.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';

import 'package:m3uxtream_player/core/services/live_audio_track_service.dart';
import 'package:m3uxtream_player/core/services/live_startup_timing.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';
import 'package:m3uxtream_player/core/services/stream_diagnostics_service.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';

import 'package:m3uxtream_player/features/diagnostics/providers/streaming_diagnostics_providers.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/services/player_diagnostics_reporter.dart';
import 'package:m3uxtream_player/features/player/services/player_event_bindings.dart';
import 'package:m3uxtream_player/features/player/services/player_playback_policies.dart';
import 'package:m3uxtream_player/features/player/vod/vod_main_video_surface_gate.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';

final selectedChannelProvider = StateProvider<Channel?>((ref) => null);

/// Immutable snapshot of the active media_kit player and its UI-facing properties.

class PlayerState {
  final Player player;

  final bool isPlaying;

  final double volume;

  final bool isBuffering;

  final bool isLiveStartupBuffering;

  final String? streamError;

  final Duration position;

  final Duration duration;

  /// Demuxer cache (`demuxer-cache-time` from mpv) — seconds of media cached.
  final Duration bufferDuration;

  final List<AudioTrack> audioTracks;

  final String? selectedAudioTrackId;

  /// Forward buffer from playhead for the VOD scrubber (ms). Reset on seek.
  final int vodForwardBufferMs;

  final String? playbackUri;

  final PlaybackMediaInfo mediaInfo;

  /// True while a live candidate is held back briefly after audio params appear,
  /// masking the mpv audio reconfiguration freeze/doubletime catch-up moment.
  final bool isLiveAudioStabilizing;

  /// True while a live candidate is settled but no selectable audio track has
  /// been exposed yet. Keeps the stream open and shows a non-blocking overlay
  /// instead of immediately stop/reopen/fallback.
  final bool isLiveAudioAwaiting;

  const PlayerState({
    required this.player,
    required this.isPlaying,
    required this.volume,
    this.isBuffering = false,
    this.isLiveStartupBuffering = false,
    this.streamError,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferDuration = Duration.zero,
    this.audioTracks = const [],
    this.selectedAudioTrackId,
    this.vodForwardBufferMs = 0,
    this.playbackUri,
    this.mediaInfo = PlaybackMediaInfo.empty,
    this.isLiveAudioStabilizing = false,
    this.isLiveAudioAwaiting = false,
  });

  bool get hasFiniteDuration => duration > Duration.zero;

  PlayerState copyWith({
    bool? isPlaying,
    double? volume,
    bool? isBuffering,
    bool? isLiveStartupBuffering,
    String? streamError,
    Duration? position,
    Duration? duration,
    Duration? bufferDuration,
    List<AudioTrack>? audioTracks,
    String? selectedAudioTrackId,
    int? vodForwardBufferMs,
    String? playbackUri,
    PlaybackMediaInfo? mediaInfo,
    bool? isLiveAudioStabilizing,
    bool? isLiveAudioAwaiting,
    bool clearStreamError = false,
    bool clearMediaInfo = false,
    bool clearPlaybackUri = false,
    bool clearSelectedAudioTrackId = false,
  }) {
    return PlayerState(
      player: player,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      isBuffering: isBuffering ?? this.isBuffering,
      isLiveStartupBuffering:
          isLiveStartupBuffering ?? this.isLiveStartupBuffering,
      streamError: clearStreamError ? null : (streamError ?? this.streamError),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferDuration: bufferDuration ?? this.bufferDuration,
      audioTracks: audioTracks ?? this.audioTracks,
      selectedAudioTrackId: clearSelectedAudioTrackId
          ? null
          : (selectedAudioTrackId ?? this.selectedAudioTrackId),
      vodForwardBufferMs: vodForwardBufferMs ?? this.vodForwardBufferMs,
      playbackUri: clearPlaybackUri ? null : (playbackUri ?? this.playbackUri),
      mediaInfo:
          mediaInfo ??
          (clearMediaInfo ? PlaybackMediaInfo.empty : this.mediaInfo),
      isLiveAudioStabilizing:
          isLiveAudioStabilizing ?? this.isLiveAudioStabilizing,
      isLiveAudioAwaiting: isLiveAudioAwaiting ?? this.isLiveAudioAwaiting,
    );
  }
}

bool isSeekableChannel(Channel? channel) {
  if (channel == null) return false;

  return channel.channelType == 'vod' || channel.channelType == 'series';
}

bool _isNonFatalStreamError(String error) {
  return PlayerStreamErrorPolicy.isNonFatal(error);
}

bool _isAudioDecodeWarning(String error) {
  return PlayerStreamErrorPolicy.isAudioDecodeWarning(error);
}

bool isIgnorablePlayerStreamError(String error) {
  return _isNonFatalStreamError(error);
}

bool isIgnorableLateSuccessfulLiveOpenError(
  String error, {
  required String? playbackUri,
  required bool isSeekable,
  required bool hasConfirmedPlayback,
  required DateTime? successfulOpenAt,
  required DateTime now,
  Duration gracePeriod = const Duration(seconds: 5),
}) {
  if (isSeekable ||
      !hasConfirmedPlayback ||
      playbackUri == null ||
      successfulOpenAt == null ||
      !_isOpenErrorMessage(error)) {
    return false;
  }

  final age = now.difference(successfulOpenAt);
  if (age < Duration.zero || age > gracePeriod) return false;

  return error.toLowerCase().contains(playbackUri.toLowerCase());
}

bool _isOpenErrorMessage(String error) {
  return PlayerStreamErrorPolicy.isOpenError(error);
}

bool isIgnorableStaleLiveOpenError(
  String error, {
  required String? currentPlaybackUri,
}) {
  if (currentPlaybackUri == null || !_isOpenErrorMessage(error)) {
    return false;
  }

  return !error.toLowerCase().contains(currentPlaybackUri.toLowerCase());
}

bool shouldRetryLiveAudioWithAutoDemuxer({
  required bool canSeek,
  required LiveStreamDelivery delivery,
  required bool recoveryAttempted,
  required String? appliedDemuxerLavfFormat,
  required List<AudioTrack> rawTracks,
  required List<AudioTrack> selectableTracks,
}) {
  if (canSeek || recoveryAttempted) return false;
  if (appliedDemuxerLavfFormat != 'mpegts') return false;
  if (!PlayerBufferService.shouldForceMpegTsDemuxer(delivery)) return false;
  if (rawTracks.isEmpty || selectableTracks.isNotEmpty) return false;
  return rawTracks.every(LiveAudioTrackService.isSpecialTrack);
}

bool shouldContinueLiveFallbackAfterAudioRecovery({
  required bool canSeek,
  required bool recoveryAttempted,
  required List<AudioTrack> rawTracks,
  required List<AudioTrack> selectableTracks,
}) {
  if (canSeek || !recoveryAttempted) return false;
  if (rawTracks.isEmpty || selectableTracks.isNotEmpty) return false;
  return rawTracks.every(LiveAudioTrackService.isSpecialTrack);
}

bool shouldContinueLiveFallbackWhenNoRealAudio({
  required bool canSeek,
  required List<AudioTrack> rawTracks,
  required List<AudioTrack> selectableTracks,
}) {
  if (canSeek || selectableTracks.isNotEmpty) return false;
  if (rawTracks.isEmpty) return true;
  return rawTracks.every(LiveAudioTrackService.isSpecialTrack);
}

/// Decides whether an extensionless continuous live candidate should be
/// abandoned quickly in favor of a later `.ts` delivery candidate instead of
/// waiting for the full track-discovery window or the late-audio wait.
///
/// This keeps Dispatcharr/Xtream proxy zaps fast: when the extensionless URL
/// only exposes `auto/no` tracks, we switch to the `.ts` variant early instead
/// of holding the HTTP connection open for the long probe/wait cycle.
bool shouldQuickSwitchToTsDeliveryCandidate({
  required bool canSeek,
  required LiveStreamDelivery delivery,
  required String playbackUrl,
  required List<AudioTrack> rawTracks,
  required List<AudioTrack> selectableTracks,
  required bool hasStreamError,
  required bool hasLaterTsCandidate,
}) {
  if (canSeek) return false;
  if (delivery != LiveStreamDelivery.continuous) return false;
  if (!LiveStreamUrl.isExtensionlessContinuousLiveUrl(playbackUrl)) {
    return false;
  }
  if (selectableTracks.isNotEmpty) return false;
  if (rawTracks.isEmpty ||
      !rawTracks.every(LiveAudioTrackService.isSpecialTrack)) {
    return false;
  }
  if (hasStreamError) return false;
  if (!hasLaterTsCandidate) return false;
  return true;
}

bool shouldRunDeferredHlsProbe({
  required bool autoFallbackEnabled,
  required bool alreadyChecked,
  required LiveStreamDelivery sourceDelivery,
  required String sourceUrl,
  required List<StreamingFallbackAttempt> attempts,
  required int currentIndex,
}) {
  if (!autoFallbackEnabled || alreadyChecked) return false;
  if (sourceDelivery != LiveStreamDelivery.continuous) return false;
  if (!LiveStreamUrl.isExtensionlessContinuousLiveUrl(sourceUrl)) return false;
  if (currentIndex <= 0 || currentIndex >= attempts.length) return false;

  return attempts[currentIndex - 1].headerProfile ==
          LiveStreamHeaderProfile.appMpv &&
      attempts[currentIndex].headerProfile != LiveStreamHeaderProfile.appMpv;
}

StreamingFallbackAttempt deferredHlsAttemptFor(String sourceUrl) {
  return StreamingFallbackAttempt(
    sourceUrl: sourceUrl,
    playbackUrl: sourceUrl,
    label: 'App/mpv deferred-hls',
    headerProfile: LiveStreamHeaderProfile.appMpv,
    deliveryType: LiveStreamDelivery.hls.diagnosticLabel,
  );
}

bool shouldReportSelectedTrackWithoutDecodedAudio({
  required List<AudioTrack> selectableTracks,
  required PlaybackMediaInfo mediaInfo,
}) {
  return selectableTracks.isNotEmpty && !mediaInfo.hasAudioInfo;
}

bool shouldContinueLiveFallbackAfterAudioDecodeFailure({
  required List<AudioTrack> selectableTracks,
  required PlaybackMediaInfo mediaInfo,
  required bool hadAudioDecodeWarning,
}) {
  return hadAudioDecodeWarning &&
      shouldReportSelectedTrackWithoutDecodedAudio(
        selectableTracks: selectableTracks,
        mediaInfo: mediaInfo,
      );
}

bool hasDecodedMultichannelAudio(PlaybackMediaInfo mediaInfo) {
  if (!mediaInfo.hasAudioInfo) return false;

  final channelCount = mediaInfo.audioChannelCount ?? 0;
  if (channelCount >= 6) return true;

  final layout = mediaInfo.audioChannelsLabel?.toLowerCase() ?? '';
  return layout.contains('5.1') || layout.contains('7.1');
}

String? decodedAudioCompatibilityHint(PlaybackMediaInfo mediaInfo) {
  if (!hasDecodedMultichannelAudio(mediaInfo)) return null;
  return 'Mehrkanalton dekodiert. Wenn kein Ton hoerbar ist, "Stereo erzwingen" testen.';
}

enum LivePlaybackFinalizationResult { released, decodeFailed, staleSession }

enum LiveAudioDecodeDecision { confirmed, provisional, failed }

enum LiveAudioWarmupResult {
  confirmed,
  provisional,
  decodeFailed,
  staleSession,
}

LiveAudioDecodeDecision classifyLiveAudioDecodeDecision({
  required bool hasRealAudioTrack,
  required bool hasDecodedAudioInfo,
  required bool hadDecodeWarning,
}) {
  if (hasDecodedAudioInfo) return LiveAudioDecodeDecision.confirmed;
  if (hadDecodeWarning) return LiveAudioDecodeDecision.failed;
  if (hasRealAudioTrack) return LiveAudioDecodeDecision.provisional;
  return LiveAudioDecodeDecision.failed;
}

Future<LiveAudioWarmupResult> waitForLiveAudioWarmup({
  required bool Function() isSessionCurrent,
  required bool Function() hasDecodedAudioInfo,
  required bool Function() hasDecodeWarning,
  Duration timeout = const Duration(milliseconds: 600),
  Duration stableWindow = const Duration(milliseconds: 200),
  Duration pollInterval = const Duration(milliseconds: 50),
  Future<void> Function(Duration duration)? delay,
  Duration Function()? elapsedNow,
}) async {
  final stopwatch = Stopwatch()..start();
  Duration elapsed() => elapsedNow?.call() ?? stopwatch.elapsed;
  final wait = delay ?? Future<void>.delayed;
  Duration? paramsObservedAt;

  while (true) {
    if (!isSessionCurrent()) return LiveAudioWarmupResult.staleSession;

    final now = elapsed();
    if (hasDecodedAudioInfo()) {
      paramsObservedAt ??= now;
      if (now - paramsObservedAt >= stableWindow) {
        return LiveAudioWarmupResult.confirmed;
      }
    } else {
      paramsObservedAt = null;
      if (hasDecodeWarning()) {
        return LiveAudioWarmupResult.decodeFailed;
      }
    }

    if (now >= timeout) return LiveAudioWarmupResult.provisional;

    final remaining = timeout - now;
    await wait(remaining < pollInterval ? remaining : pollInterval);
  }
}

enum VodPreBufferWaitStatus { waiting, reached, cancelled, timedOut }

Future<LivePlaybackFinalizationResult> finalizePreparedLiveCandidatePlayback({
  required bool shouldAutoSelectAudioTrack,
  required bool shouldEvaluateAudioDecode,
  required Future<void> Function() applyBestTrack,
  required Future<LiveAudioDecodeDecision> Function() classifyDecodedAudio,
  required Future<LivePlaybackFinalizationResult> Function(
    LiveAudioDecodeDecision decision,
  )
  releasePlayback,
}) async {
  if (shouldAutoSelectAudioTrack) {
    await applyBestTrack();
  }

  final decision = shouldEvaluateAudioDecode
      ? await classifyDecodedAudio()
      : LiveAudioDecodeDecision.confirmed;
  if (decision == LiveAudioDecodeDecision.failed) {
    return LivePlaybackFinalizationResult.decodeFailed;
  }

  return releasePlayback(decision);
}

VodPreBufferWaitStatus classifyVodPreBufferWait({
  required Duration buffered,
  required int targetSeconds,
  required DateTime now,
  required DateTime deadline,
  required bool isDisposed,
  required bool isCurrentSession,
}) {
  if (isDisposed || !isCurrentSession) {
    return VodPreBufferWaitStatus.cancelled;
  }
  if (targetSeconds <= 0 || buffered.inSeconds >= targetSeconds) {
    return VodPreBufferWaitStatus.reached;
  }
  if (!now.isBefore(deadline)) {
    return VodPreBufferWaitStatus.timedOut;
  }
  return VodPreBufferWaitStatus.waiting;
}

/// Result of waiting for the user-configured live startup buffer.
enum LiveStartupBufferWaitResult { reached, timedOut, cancelled }

/// Waits until [currentBuffer] reaches [target], the [timeout] expires, or the
/// session becomes stale. Exposed as a top-level helper so the polling logic
/// can be unit-tested without a real media_kit player.
Future<LiveStartupBufferWaitResult> waitForLiveStartupBuffer({
  required Duration target,
  required Duration timeout,
  required Duration pollInterval,
  required Future<bool> Function() isSessionCurrent,
  required Future<Duration> Function() currentBuffer,
}) async {
  if (target <= Duration.zero || timeout <= Duration.zero) {
    return LiveStartupBufferWaitResult.reached;
  }

  final startedAt = DateTime.now();
  while (DateTime.now().difference(startedAt) < timeout) {
    if (!await isSessionCurrent()) return LiveStartupBufferWaitResult.cancelled;
    final buffer = await currentBuffer();
    if (buffer >= target) return LiveStartupBufferWaitResult.reached;
    await Future<void>.delayed(pollInterval);
  }

  if (!await isSessionCurrent()) return LiveStartupBufferWaitResult.cancelled;
  return LiveStartupBufferWaitResult.timedOut;
}

/// Result of waiting briefly for a late audio track on a healthy live candidate.
enum LateAudioWaitResult { skipped, cancelled, timedOut, tracksFound }

/// Keeps a settled live stream open and waits for real audio tracks to appear.
///
/// This avoids the stop/reopen/fallback cycle for proxy/continuous streams
/// (e.g. Dispatcharr) that expose audio with a short delay. It only waits when
/// the candidate is otherwise healthy: no stream error, raw tracks are only
/// `auto/no`, and the delivery is continuous or raw TS.
Future<({LateAudioWaitResult result, List<AudioTrack> selectable})>
waitForLateLiveAudioTracks({
  required LiveStreamDelivery delivery,
  required Tracks Function() currentTracks,
  required bool Function() isSessionCurrent,
  required bool Function() hasStreamError,
  Duration timeout = const Duration(seconds: 12),
  Duration pollInterval = const Duration(milliseconds: 200),
}) async {
  if (!isSessionCurrent()) {
    return (
      result: LateAudioWaitResult.cancelled,
      selectable: const <AudioTrack>[],
    );
  }

  if (delivery != LiveStreamDelivery.continuous &&
      delivery != LiveStreamDelivery.tsSegment) {
    return (
      result: LateAudioWaitResult.skipped,
      selectable: LiveAudioTrackService.selectableTracks(currentTracks()),
    );
  }

  if (hasStreamError()) {
    return (
      result: LateAudioWaitResult.skipped,
      selectable: LiveAudioTrackService.selectableTracks(currentTracks()),
    );
  }

  final rawTracks = currentTracks().audio;
  final selectable = LiveAudioTrackService.selectableTracks(currentTracks());
  if (selectable.isNotEmpty) {
    return (result: LateAudioWaitResult.tracksFound, selectable: selectable);
  }
  if (rawTracks.isEmpty ||
      !rawTracks.every(LiveAudioTrackService.isSpecialTrack)) {
    return (result: LateAudioWaitResult.skipped, selectable: selectable);
  }

  AppLogger.info(
    'PlayerNotifier: Late audio wait started '
    '(delivery=${delivery.diagnosticLabel}, timeout=${timeout.inSeconds}s).',
  );

  final startedAt = DateTime.now();
  while (DateTime.now().difference(startedAt) < timeout) {
    if (!isSessionCurrent()) {
      AppLogger.info(
        'PlayerNotifier: Late audio wait cancelled by new session.',
      );
      return (
        result: LateAudioWaitResult.cancelled,
        selectable: const <AudioTrack>[],
      );
    }
    if (hasStreamError()) {
      AppLogger.info(
        'PlayerNotifier: Late audio wait aborted due to stream error.',
      );
      return (
        result: LateAudioWaitResult.skipped,
        selectable: const <AudioTrack>[],
      );
    }

    final currentSelectable = LiveAudioTrackService.selectableTracks(
      currentTracks(),
    );
    if (currentSelectable.isNotEmpty) {
      AppLogger.info(
        'PlayerNotifier: Late audio wait found ${currentSelectable.length} selectable track(s).',
      );
      return (
        result: LateAudioWaitResult.tracksFound,
        selectable: currentSelectable,
      );
    }

    await Future<void>.delayed(pollInterval);
  }

  AppLogger.warning(
    'PlayerNotifier: Late audio wait timed out; continuing fallback.',
  );
  return (
    result: LateAudioWaitResult.timedOut,
    selectable: const <AudioTrack>[],
  );
}

/// Manages the singleton media_kit [Player] lifecycle and reactive playback state.

class PlayerNotifier extends AsyncNotifier<PlayerState> {
  static const _defaultUnmuteVolume = 0.8;
  static const _audioWarningThrottle = Duration(seconds: 5);

  static const _bestEffortAudioWatchWindow = Duration(seconds: 5);
  static const _lateAudioWaitTimeout = Duration(seconds: 12);
  static const _lateAudioWaitPollInterval = Duration(milliseconds: 200);

  /// Short discovery window for extensionless continuous live candidates that
  /// have a `.ts` fallback available. Lets mpv expose PMT audio without paying
  /// the full analyzeduration cost, while keeping Dispatcharr/Proxy zaps fast.
  static const _quickAudioProbeTimeout = Duration(seconds: 2);

  double? _volumeBeforeMute;

  VideoController? _videoController;

  final PlayerEventBindings _eventBindings = PlayerEventBindings();
  final PlayerDiagnosticsReporter _diagnosticsReporter =
      const PlayerDiagnosticsReporter();

  DateTime? _lastSuccessfulOpenAt;
  String? _lastAudioTrackSignature;
  LiveStreamDelivery? _lastAppliedLiveDelivery;
  String? _lastAppliedDemuxerLavfFormat;
  String? _manualAudioTrackId;
  int _liveOpenSessionToken = 0;
  Future<void>? _disposeFuture;
  Future<PlayerState>? _initFuture;
  String? _lastAudioWarning;
  DateTime? _lastAudioWarningAt;
  bool _audioDisabledByWatchdog = false;
  bool _isDisposed = false;
  bool _forceStereoEnabled = false;
  String? _preferredAudioLanguage;

  // Live audio stabilization indicators, reset per live open session.
  bool _liveAudioInitialAutoOnly = false;
  bool _liveAudioHadNoAudioState = false;
  bool _liveAudioTrackSwitchedDuringPrep = false;
  String? _liveAudioSelectedTrackId;

  void _invalidateVideoController() {
    _videoController = null;
  }

  Future<void> _applyAudioCompatibility(Player player) async {
    final forceStereoEnabled = await ref.read(
      forceStereoEnabledProvider.future,
    );
    final preferredLanguage = await ref.read(
      preferredAudioLanguageProvider.future,
    );
    _forceStereoEnabled = forceStereoEnabled;
    _preferredAudioLanguage = preferredLanguage;
    await PlayerBufferService.applyAudioCompatibility(
      player,
      forceStereo: forceStereoEnabled,
    );
  }

  int _beginLiveOpenSession() {
    _liveOpenSessionToken += 1;
    return _liveOpenSessionToken;
  }

  bool _isLiveOpenSessionCurrent(int sessionToken) {
    return sessionToken == _liveOpenSessionToken;
  }

  StreamingDiagnosticsSettings _streamingDiagnosticsSettings() {
    return ref.read(streamingDiagnosticsSettingsProvider).valueOrNull ??
        const StreamingDiagnosticsSettings(
          autoFallbackEnabled:
              StreamingDiagnosticsSettingsNotifier.defaultAutoFallbackEnabled,
          showOnErrorEnabled:
              StreamingDiagnosticsSettingsNotifier.defaultShowOnErrorEnabled,
        );
  }

  void _recordStreamingDiagnostic({
    required StreamingDiagnosticPhase phase,
    required Channel? channel,
    required StreamingFallbackAttempt attempt,
    StreamingFailureKind? failureKind,
    String? mpvError,
    int? httpStatus,
    String? contentType,
    String? deliveryType,
    Duration duration = Duration.zero,
    String? diagnosisNote,
  }) {
    ref
        .read(streamingDiagnosticsProvider.notifier)
        .record(
          _diagnosticsReporter.createStreamingEvent(
            timestamp: DateTime.now(),
            phase: phase,
            channel: channel,
            attempt: attempt,
            deliveryType: deliveryType ?? attempt.deliveryType,
            httpStatus: httpStatus,
            contentType: contentType,
            mpvError: mpvError,
            failureKind: failureKind,
            duration: duration,
            diagnosisNote: diagnosisNote,
          ),
        );
  }

  void _logStreamingFailureToUi(String message) {
    ref
        .read(uiLogsProvider.notifier)
        .addLog(redactStreamText('Streaming: $message'));
  }

  void _logAudioWarningToUi(String message) {
    ref
        .read(uiLogsProvider.notifier)
        .addLog(redactStreamText('Audio: $message'));
  }

  String _audioTrackSignature(Iterable<AudioTrack> tracks) {
    return tracks
        .map(
          (track) =>
              '${track.id}:${track.codec ?? ''}:${track.language ?? ''}:${track.title ?? ''}:${track.channelscount ?? ''}:${track.channels ?? ''}',
        )
        .join('|');
  }

  void _logAudioDiagnosticsSnapshot({
    required Player player,
    required String stage,
    required List<AudioTrack> rawTracks,
    required List<AudioTrack> selectableTracks,
    required bool forceStereoEnabled,
    required LiveStreamDelivery delivery,
  }) {
    final current = state.asData?.value;
    _diagnosticsReporter.logAudioSnapshot(
      player: player,
      stage: stage,
      rawTracks: rawTracks,
      selectableTracks: selectableTracks,
      forceStereoEnabled: forceStereoEnabled,
      delivery: delivery,
      appliedDemuxerLavfFormat: _lastAppliedDemuxerLavfFormat,
      selectedAudioTrackId: current?.selectedAudioTrackId,
      mediaInfo: current?.mediaInfo,
      streamError: current?.streamError,
    );
  }

  Future<void> _logAudioDiagnosticsSnapshotAsync({
    required Player player,
    required String stage,
    required List<AudioTrack> rawTracks,
    required List<AudioTrack> selectableTracks,
    required LiveStreamDelivery delivery,
  }) async {
    bool forceStereoEnabled = false;
    try {
      forceStereoEnabled = await ref.read(forceStereoEnabledProvider.future);
    } catch (e) {
      AppLogger.info(
        'PlayerNotifier: Audio diagnostics could not read the force stereo flag: ${redactStreamText(e.toString())}',
      );
    }
    if (_isDisposed) return;
    _logAudioDiagnosticsSnapshot(
      player: player,
      stage: stage,
      rawTracks: rawTracks,
      selectableTracks: selectableTracks,
      forceStereoEnabled: forceStereoEnabled,
      delivery: delivery,
    );
  }

  VideoController videoControllerFor(Player player) {
    _videoController ??= VideoController(player);
    return _videoController!;
  }

  Future<void> disposeResources() {
    final existing = _disposeFuture;
    if (existing != null) return existing;

    final future = _disposeResourcesImpl();
    _disposeFuture = future;
    return future;
  }

  Future<void> _disposeResourcesImpl() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _beginLiveOpenSession();

    await _eventBindings.dispose();

    _invalidateVideoController();

    final current = state.asData?.value;
    if (current != null) {
      try {
        await current.player.dispose();
      } catch (e, stackTrace) {
        AppLogger.error(
          'PlayerNotifier: Failed to dispose media_kit player',
          e,
          stackTrace,
        );
      }
    }
  }

  /// Resumes VOD/series after prep — does not recreate the video controller.
  Future<void> startVodPreparedPlayback() async {
    final current = state.asData?.value;
    if (current == null || !_hasActiveStream) return;
    if (!isSeekableChannel(ref.read(selectedChannelProvider))) return;
    await current.player.play();
  }

  @override
  Future<PlayerState> build() async {
    _initFuture ??= _initializePlayer();
    return _initFuture!;
  }

  Future<PlayerState> _initializePlayer() async {
    // Yield to the UI event loop first so the window chrome can render and
    // become interactive before the heavy native player initialization runs.
    await Future<void>.delayed(Duration.zero);

    final stopwatch = Stopwatch()..start();

    final bufferSeconds = await ref.read(playerBufferSecondsProvider.future);
    final technicalLiveReadAheadSeconds =
        liveTechnicalReadAheadSecondsForStartupSeconds(bufferSeconds);

    final player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferSizeBytesForSeconds(technicalLiveReadAheadSeconds),
      ),
    );

    await PlayerBufferService.applyPlaybackProfile(
      player,
      isLive: true,
      preloadSeconds: bufferSeconds,
    );
    await _applyAudioCompatibility(player);

    _eventBindings.bind(
      player,
      onPlaying: (playing) {
        _update((s) => s.copyWith(isPlaying: playing));
      },
      onVolume: (volume) {
        _update((s) => s.copyWith(volume: volume / 100.0));
      },
      onBuffering: (buffering) {
        if (!_hasActiveStream) return;
        _update((s) => s.copyWith(isBuffering: buffering));
      },
      onError: _handleStreamError,
      onPosition: (position) {
        if (!_hasActiveStream) return;
        _update((s) => s.copyWith(position: position));
      },
      onDuration: (duration) {
        if (!_hasActiveStream) return;
        _update((s) => s.copyWith(duration: duration));
      },
      onBuffer: (buffer) {
        if (!_hasActiveStream) return;
        final capped = _capBufferDuration(buffer);
        _update((s) {
          final next = s.copyWith(bufferDuration: capped);
          if (!isSeekableChannel(ref.read(selectedChannelProvider))) {
            return next;
          }
          return _applyVodForwardBuffer(next, capped);
        });
      },
      onTracks: (tracks) {
        if (!_hasCurrentPlayback) return;

        if (_audioDisabledByWatchdog) {
          AppLogger.info(
            'PlayerNotifier: Audio auto-selection skipped (disabled by watchdog).',
          );
          return;
        }

        final rawTracks = tracks.audio;
        final selectable = LiveAudioTrackService.selectableTracks(tracks);
        final signature = _audioTrackSignature(rawTracks);

        _update(
          (s) => s.copyWith(
            audioTracks: selectable,
            selectedAudioTrackId: _manualAudioTrackId,
          ),
        );

        if (signature == _lastAudioTrackSignature) return;
        _lastAudioTrackSignature = signature;

        final current = state.asData?.value;
        final playbackUri = current?.playbackUri;
        final delivery =
            _lastAppliedLiveDelivery ??
            (playbackUri == null
                ? LiveStreamDelivery.continuous
                : LiveStreamUrl.deliveryFor(playbackUri));

        unawaited(
          _logAudioDiagnosticsSnapshotAsync(
            player: player,
            stage: 'tracks update',
            rawTracks: rawTracks,
            selectableTracks: selectable,
            delivery: delivery,
          ),
        );

        if (selectable.isEmpty) {
          AppLogger.info(
            'PlayerNotifier: No selectable audio tracks detected yet.',
          );
          return;
        }

        AppLogger.info(
          'PlayerNotifier: Detected ${selectable.length} selectable audio track(s).',
        );

        if (_manualAudioTrackId == null) {
          unawaited(
            LiveAudioTrackService.applyBestTrack(
              player,
              tracks: selectable,
              preferStereo: _forceStereoEnabled,
              preferredLanguage: _preferredAudioLanguage,
            ),
          );
        }

        // Detect a track switch that happened while we were still preparing the
        // live candidate (e.g. late audio PID exposed a different track).
        final selectedId = player.state.track.audio.id;
        if (_liveAudioSelectedTrackId != null &&
            selectedId != _liveAudioSelectedTrackId &&
            !LiveAudioTrackService.isSpecialTrack(player.state.track.audio)) {
          _liveAudioTrackSwitchedDuringPrep = true;
          AppLogger.info(
            'PlayerNotifier: Audio track switched during live preparation '
            '(was $_liveAudioSelectedTrackId, now $selectedId)',
          );
        }
      },
      onVideoParams: (params) {
        if (!_hasCurrentPlayback) return;
        _update(
          (s) => s.copyWith(
            mediaInfo: s.mediaInfo.copyWith(
              videoWidth: params.dw ?? params.w,
              videoHeight: params.dh ?? params.h,
              videoPixelFormat: params.pixelformat,
            ),
          ),
        );
      },
      onAudioParams: (params) {
        if (!_hasCurrentPlayback) return;
        _update(
          (s) => s.copyWith(
            mediaInfo: s.mediaInfo.copyWith(
              audioFormat: params.format,
              audioSampleRate: params.sampleRate,
              audioChannelCount: params.channelCount,
              audioChannelsLabel: params.hrChannels ?? params.channels,
            ),
          ),
        );
      },
      onAudioBitrate: (bitrate) {
        if (!_hasCurrentPlayback) return;
        _update(
          (s) => s.copyWith(
            mediaInfo: s.mediaInfo.copyWith(audioBitrateKbps: bitrate),
          ),
        );
      },
    );

    ref.onDispose(() {
      AppLogger.info('PlayerNotifier: Disposing media_kit player.');
      unawaited(disposeResources());
    });

    await player.setVolume(80.0);

    AppLogger.info(
      'PlayerNotifier: media_kit player initialized (preload ${bufferSeconds}s).',
    );

    AppLogger.debug(
      'PlayerNotifier: Player initialized in ${stopwatch.elapsedMilliseconds}ms',
    );

    return PlayerState(
      player: player,
      isPlaying: player.state.playing,
      volume: player.state.volume / 100.0,
      position: player.state.position,
      duration: player.state.duration,
      bufferDuration: player.state.buffer,
      audioTracks: LiveAudioTrackService.selectableTracks(player.state.tracks),
      selectedAudioTrackId: null,
      isLiveStartupBuffering: false,
      isLiveAudioStabilizing: false,
      isLiveAudioAwaiting: false,
    );
  }

  void _handleStreamError(String error) {
    if (isIgnorablePlayerStreamError(error)) {
      if (_isAudioDecodeWarning(error)) {
        _logNonFatalAudioDecodeWarning(error);
      }
      // Logged at debug only — these come every few seconds for IPTV and aren't actionable.
      // Switching audio tracks here caused video resync (gray flash + audio repeat).
      return;
    }

    final current = state.asData?.value;
    if (current != null &&
        isIgnorableLateSuccessfulLiveOpenError(
          error,
          playbackUri: current.playbackUri,
          isSeekable: isSeekableChannel(ref.read(selectedChannelProvider)),
          hasConfirmedPlayback:
              current.isPlaying ||
              current.player.state.playing ||
              current.position > Duration.zero ||
              current.bufferDuration > Duration.zero,
          successfulOpenAt: _lastSuccessfulOpenAt,
          now: DateTime.now(),
        )) {
      AppLogger.info(
        'PlayerNotifier: Ignoring late live open error after confirmed playback.',
      );
      return;
    }

    if (isIgnorableStaleLiveOpenError(
      error,
      currentPlaybackUri: current?.playbackUri,
    )) {
      AppLogger.info(
        'PlayerNotifier: Ignoring stale live open error for superseded playback.',
      );
      return;
    }

    AppLogger.error('PlayerNotifier: Stream error', redactStreamText(error));

    _update((s) => s.copyWith(streamError: error));
  }

  void _update(PlayerState Function(PlayerState current) transform) {
    if (_isDisposed) return;
    final current = state.asData?.value;

    if (current != null) {
      state = AsyncData(transform(current));
    }
  }

  bool get _hasActiveStream => ref.read(selectedChannelProvider) != null;

  bool get _hasCurrentPlayback {
    final current = state.asData?.value;
    return current?.playbackUri != null &&
        ref.read(selectedChannelProvider) != null;
  }

  void _logNonFatalAudioDecodeWarning(String error) {
    final now = DateTime.now();
    if (_lastAudioWarning == error &&
        _lastAudioWarningAt != null &&
        now.difference(_lastAudioWarningAt!) < _audioWarningThrottle) {
      return;
    }

    _lastAudioWarning = error;
    _lastAudioWarningAt = now;
    final redacted = redactStreamText(error);
    AppLogger.warning(
      'PlayerNotifier: Non-fatal audio decode warning',
      redacted,
    );
    _logAudioWarningToUi('Decode warning: $redacted');
  }

  AudioTrack? _findAudioTrackById(PlayerState current, String trackId) {
    for (final track in current.audioTracks) {
      if (track.id == trackId) return track;
    }
    for (final track in current.player.state.tracks.audio) {
      if (track.id == trackId) return track;
    }
    return null;
  }

  PlayerState _applyVodForwardBuffer(PlayerState s, Duration buffer) {
    final cacheMs = buffer.inMilliseconds;
    if (cacheMs <= 0) {
      return s.copyWith(vodForwardBufferMs: 0);
    }
    if (s.isBuffering) {
      return s.copyWith(
        vodForwardBufferMs: cacheMs.clamp(
          0,
          PlayerBufferService.vodPreBufferCacheSeconds * 1000,
        ),
      );
    }
    return s;
  }

  Duration _capBufferDuration(Duration buffer) {
    if (isSeekableChannel(ref.read(selectedChannelProvider))) {
      return buffer;
    }
    final maxSecs =
        ref.read(playerBufferSecondsProvider).valueOrNull ??
        PlayerBufferSecondsNotifier.defaultSeconds;
    final maxMs = (maxSecs <= 0 ? 3 : maxSecs) * 1000;
    if (buffer.inMilliseconds <= maxMs) return buffer;
    return Duration(milliseconds: maxMs);
  }

  Future<void> togglePlay() async {
    final current = state.asData?.value;

    if (current == null || !_hasActiveStream) return;

    await current.player.playOrPause();
  }

  Future<void> adjustVolume(double delta) async {
    final current = state.asData?.value;

    if (current == null) return;

    final newVolume = ((current.volume + delta) * 100.0).clamp(0.0, 100.0);

    await current.player.setVolume(newVolume);
  }

  Future<void> setVolumeNormalized(double normalized) async {
    final current = state.asData?.value;

    if (current == null) return;

    await current.player.setVolume((normalized * 100.0).clamp(0.0, 100.0));
  }

  Future<void> toggleMute() async {
    final current = state.asData?.value;

    if (current == null) return;

    if (current.volume > 0) {
      _volumeBeforeMute = current.volume;

      await current.player.setVolume(0);
    } else {
      final restore = _volumeBeforeMute ?? _defaultUnmuteVolume;

      await current.player.setVolume((restore * 100.0).clamp(0.0, 100.0));
    }
  }

  Future<void> selectAudioTrack(String trackId) async {
    final current = state.asData?.value;
    if (current == null || !_hasActiveStream) return;

    if (trackId == AudioTrack.auto().id) {
      _manualAudioTrackId = null;
      _update((s) => s.copyWith(clearSelectedAudioTrackId: true));
      try {
        await current.player.setAudioTrack(AudioTrack.auto());
        AppLogger.info('PlayerNotifier: Audio track selected: Auto');
      } catch (e, stackTrace) {
        AppLogger.error(
          'PlayerNotifier: Audio track switch failed',
          e,
          stackTrace,
        );
        ref
            .read(uiLogsProvider.notifier)
            .addLog('Audio track switch failed: Auto');
      }
      return;
    }

    final track = _findAudioTrackById(current, trackId);
    if (track == null) {
      AppLogger.error(
        'PlayerNotifier: Audio track switch failed',
        'Track $trackId not available.',
      );
      ref
          .read(uiLogsProvider.notifier)
          .addLog('Audio track switch failed: Track not available');
      return;
    }

    try {
      _manualAudioTrackId = track.id;
      _update((s) => s.copyWith(selectedAudioTrackId: track.id));
      await current.player.setAudioTrack(track);
      AppLogger.info(
        'PlayerNotifier: Audio track selected: ${LiveAudioTrackService.labelFor(track)}',
      );
    } catch (e, stackTrace) {
      _manualAudioTrackId = null;
      _update((s) => s.copyWith(clearSelectedAudioTrackId: true));
      AppLogger.error(
        'PlayerNotifier: Audio track switch failed',
        e,
        stackTrace,
      );
      ref
          .read(uiLogsProvider.notifier)
          .addLog(
            'Audio track switch failed: ${LiveAudioTrackService.labelFor(track)}',
          );
    }
  }

  Future<void> seek(Duration position) async {
    if (!isSeekableChannel(ref.read(selectedChannelProvider))) return;

    final current = state.asData?.value;
    if (current == null) return;

    final duration = current.duration;
    var target = position;
    if (duration > Duration.zero && target > duration) {
      target = duration;
    }
    if (target < Duration.zero) target = Duration.zero;

    final wasPlaying = current.player.state.playing;
    final preBuffer = ref.read(vodPreBufferEnabledProvider).valueOrNull ?? true;
    final bufferSeconds =
        ref.read(playerBufferSecondsProvider).valueOrNull ??
        PlayerBufferSecondsNotifier.defaultSeconds;

    _update((s) => s.copyWith(vodForwardBufferMs: 0, isBuffering: true));

    try {
      await PlayerBufferService.applyVodPlaybackProfile(
        current.player,
        preloadSeconds: bufferSeconds,
        aggressivePreload: preBuffer,
      );
      await current.player.seek(target);
      if (wasPlaying) {
        await current.player.play();
      }
    } catch (e, stackTrace) {
      AppLogger.error('PlayerNotifier: Seek failed', e, stackTrace);
      _update((s) => s.copyWith(isBuffering: false));
    }
  }

  Future<void> stopStream() async {
    final current = state.asData?.value;

    if (current == null) return;

    AppLogger.info('PlayerNotifier: Stopping playback.');
    _beginLiveOpenSession();
    _manualAudioTrackId = null;
    _lastAudioTrackSignature = null;
    _lastAppliedLiveDelivery = null;
    _lastAppliedDemuxerLavfFormat = null;
    _lastAudioWarning = null;
    _lastAudioWarningAt = null;
    _audioDisabledByWatchdog = false;
    _liveAudioInitialAutoOnly = false;
    _liveAudioHadNoAudioState = false;
    _liveAudioTrackSwitchedDuringPrep = false;
    _liveAudioSelectedTrackId = null;

    await current.player.stop();

    resetVodMainVideoSurfaceReady(ref);
    _invalidateVideoController();

    ref.read(selectedChannelProvider.notifier).state = null;

    _update(
      (s) => s.copyWith(
        isPlaying: false,
        isBuffering: false,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        position: Duration.zero,
        duration: Duration.zero,
        bufferDuration: Duration.zero,
        audioTracks: const [],
        clearSelectedAudioTrackId: true,
        vodForwardBufferMs: 0,
        clearPlaybackUri: true,
        clearStreamError: true,
        clearMediaInfo: true,
      ),
    );
  }

  Future<void> openStream(
    String url, {
    Duration? startPosition,
    bool startPaused = false,
    bool preBuffer = false,
  }) async {
    if (state.isLoading && _initFuture != null) {
      await _initFuture;
    }

    final current = state.asData?.value;

    if (current == null) {
      AppLogger.warning(
        'PlayerNotifier: openStream called but player state is not ready.',
      );
      return;
    }

    final channel = ref.read(selectedChannelProvider);

    final canSeek = isSeekableChannel(channel);
    final sessionToken = _beginLiveOpenSession();
    _manualAudioTrackId = null;
    _lastAudioTrackSignature = null;
    _lastAppliedLiveDelivery = null;
    _lastAppliedDemuxerLavfFormat = null;
    _lastAudioWarning = null;
    _lastAudioWarningAt = null;
    _audioDisabledByWatchdog = false;
    _liveAudioInitialAutoOnly = false;
    _liveAudioHadNoAudioState = false;
    _liveAudioTrackSwitchedDuringPrep = false;
    _liveAudioSelectedTrackId = null;
    _update(
      (s) => s.copyWith(
        audioTracks: const [],
        clearSelectedAudioTrackId: true,
        clearPlaybackUri: true,
        clearMediaInfo: true,
        // Show the preparation overlay immediately for live streams, even
        // before the actual playbackUri is set and the Video surface mounts.
        isPlaying: !canSeek ? false : s.isPlaying,
        isBuffering: !canSeek || s.isBuffering,
      ),
    );

    if (!canSeek) {
      final timing = LiveStartupTiming()..start();
      try {
        final settings = _streamingDiagnosticsSettings();
        final liveStartupBufferSeconds =
            ref.read(playerBufferSecondsProvider).valueOrNull ??
            PlayerBufferSecondsNotifier.defaultSeconds;
        final liveStartupBufferEnabled = liveStartupBufferSeconds > 0;
        final allAttempts = LiveStreamUrl.playbackAttempts(url);
        final sourceDelivery = LiveStreamUrl.deliveryFor(url);
        final sourcePlaybackUrl = url.trim();
        final attempts = settings.autoFallbackEnabled
            ? allAttempts.toList(growable: true)
            : allAttempts.take(1).toList(growable: false);
        var hlsProbeChecked = false;
        StreamConnectionProbeResult? hlsProbeResult;
        // Auto-demuxer audio recovery is allowed once per header profile so the
        // VLC-like/browser-like candidates also get the large-probe retry.
        final attemptedRecoveryProfiles = <LiveStreamHeaderProfile>{};
        var liveAudioFallbackNeedsHeaderProfileRetryLog = false;
        var liveAudioRecoveryFallbackFailed = false;

        if (current.playbackUri != null) {
          await _stopLivePlaybackForRetry(current.player, sessionToken);
          if (!_isLiveOpenSessionCurrent(sessionToken)) return;
        }

        Object? lastError;
        StreamFailureClassification? lastClassification;

        for (
          var attemptIndex = 0;
          attemptIndex < attempts.length;
          attemptIndex++
        ) {
          if (!_isLiveOpenSessionCurrent(sessionToken)) return;

          var probedThisAttempt = false;
          if (shouldRunDeferredHlsProbe(
            autoFallbackEnabled: settings.autoFallbackEnabled,
            alreadyChecked: hlsProbeChecked,
            sourceDelivery: sourceDelivery,
            sourceUrl: sourcePlaybackUrl,
            attempts: attempts,
            currentIndex: attemptIndex,
          )) {
            hlsProbeChecked = true;
            probedThisAttempt = true;
            await timing.measure(LiveStartupPhase.hlsProbe, () async {
              try {
                hlsProbeResult = await StreamDiagnosticsService.probeStreamUrl(
                  sourcePlaybackUrl,
                  headers: LiveStreamHeaderProfile.appMpv.headers,
                  timeout: const Duration(milliseconds: 1200),
                );
              } catch (e) {
                hlsProbeResult = null;
                AppLogger.info(
                  'PlayerNotifier: Deferred HLS probe skipped for '
                  '${redactStreamUrl(sourcePlaybackUrl)}: '
                  '${redactStreamText(e.toString())}',
                );
              }
            });
            if (!_isLiveOpenSessionCurrent(sessionToken)) return;

            if (hlsProbeResult?.looksLikeHls == true) {
              attempts.insert(
                attemptIndex,
                deferredHlsAttemptFor(sourcePlaybackUrl),
              );
            } else {
              AppLogger.info(
                'PlayerNotifier: Deferred HLS probe found no HLS; '
                'continuing header fallbacks.',
              );
            }
          }

          final attempt = attempts[attemptIndex];
          if (liveAudioFallbackNeedsHeaderProfileRetryLog &&
              attempt.headerProfile != LiveStreamHeaderProfile.appMpv) {
            AppLogger.info(
              'PlayerNotifier: Trying ${attempt.headerProfile.label} header profile after audio-less live open',
            );
            liveAudioFallbackNeedsHeaderProfileRetryLog = false;
          }
          final startedAt = DateTime.now();
          final attemptPlaybackUri = attempt.playbackUrl;
          final probe = attemptPlaybackUri == sourcePlaybackUrl
              ? hlsProbeResult
              : null;
          final effectiveDelivery = LiveStreamUrl.deliveryFor(
            attemptPlaybackUri,
            looksLikeHls: probe?.looksLikeHls,
          );
          timing.recordCandidate(
            attemptLabel: attempt.label,
            headerProfile: attempt.headerProfile.label,
            delivery: effectiveDelivery.diagnosticLabel,
          );

          // Quick audio probe is only considered for extensionless continuous
          // live proxies that still have a .ts delivery candidate later in the
          // fallback list. This avoids the expensive full analyzeduration window
          // and late-audio wait on the first candidate when a .ts variant is
          // likely to expose audio faster.
          final quickSwitchStructurallyEligible =
              !canSeek &&
              effectiveDelivery == LiveStreamDelivery.continuous &&
              LiveStreamUrl.isExtensionlessContinuousLiveUrl(
                attemptPlaybackUri,
              ) &&
              LiveStreamUrl.hasLaterTsCandidate(attempts, attemptIndex);

          if (probedThisAttempt && probe?.looksLikeHls == true) {
            final hintSuffix = probe?.hlsHintSummary == null
                ? ''
                : ' (${probe!.hlsHintSummary})';
            AppLogger.info(
              'PlayerNotifier: HLS probe detected for ${redactStreamUrl(attemptPlaybackUri)}$hintSuffix',
            );
          }
          _recordStreamingDiagnostic(
            phase: StreamingDiagnosticPhase.started,
            channel: channel,
            attempt: attempt,
            deliveryType: effectiveDelivery.diagnosticLabel,
            diagnosisNote: probe?.hlsHintSummary != null
                ? 'HLS probe: ${probe!.hlsHintSummary}'
                : (probe?.looksLikeHls == true ? 'HLS probe detected' : null),
          );
          try {
            final openResult = await timing.measure(
              LiveStartupPhase.openAndSettle,
              () async {
                final opened = await _openStreamInternal(
                  current: current,
                  sourceUrl: url,
                  playbackUrl: attemptPlaybackUri,
                  canSeek: canSeek,
                  startPosition: startPosition,
                  startPaused: startPaused,
                  preBuffer: preBuffer,
                  sessionToken: sessionToken,
                  httpHeaders: attempt.headers,
                  liveStartupBuffer: false,
                  liveDelivery: effectiveDelivery,
                  openPaused: !canSeek,
                );
                if (!opened || !_isLiveOpenSessionCurrent(sessionToken)) {
                  return (opened: opened, settled: false);
                }
                final settled = await _waitForStreamSettled(
                  current.player,
                  requirePlaying: false,
                );
                return (opened: opened, settled: settled);
              },
            );
            final opened = openResult.opened;
            final settled = openResult.settled;

            if (!opened || !_isLiveOpenSessionCurrent(sessionToken)) return;

            if (!_isLiveOpenSessionCurrent(sessionToken)) return;

            if (settled) {
              var sawAnyRealTrack = false;
              _liveAudioInitialAutoOnly = false;
              _liveAudioHadNoAudioState = false;

              // Use a short probe window for quick-switch candidates; otherwise
              // keep the existing analyzeduration-based window so normal channels
              // get their full discovery time.
              final trackWaitTimeout = quickSwitchStructurallyEligible
                  ? _quickAudioProbeTimeout
                  : liveTrackWaitTimeoutForAnalyzeSeconds(
                      PlayerBufferService.liveAnalyzeDurationSeconds,
                    );

              var selectable = await timing.measure(
                LiveStartupPhase.initialTracks,
                () => LiveAudioTrackService.waitForSelectableTracks(
                  current.player,
                  timeout: trackWaitTimeout,
                  onProgress: (tracks, selectableTracks) {
                    if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                    if (selectableTracks.isEmpty) {
                      _liveAudioHadNoAudioState = true;
                      if (!sawAnyRealTrack) {
                        _liveAudioInitialAutoOnly = true;
                      }
                    } else {
                      sawAnyRealTrack = true;
                    }
                    unawaited(
                      _logAudioDiagnosticsSnapshotAsync(
                        player: current.player,
                        stage: 'startup poll',
                        rawTracks: tracks.audio,
                        selectableTracks: selectableTracks,
                        delivery: _lastAppliedLiveDelivery ?? effectiveDelivery,
                      ),
                    );
                  },
                ),
              );
              if (!_isLiveOpenSessionCurrent(sessionToken)) return;

              var rawTracks = current.player.state.tracks.audio;

              final quickSwitchEligible =
                  shouldQuickSwitchToTsDeliveryCandidate(
                    canSeek: canSeek,
                    delivery: effectiveDelivery,
                    playbackUrl: attemptPlaybackUri,
                    rawTracks: rawTracks,
                    selectableTracks: selectable,
                    hasStreamError: state.asData?.value.streamError != null,
                    hasLaterTsCandidate: LiveStreamUrl.hasLaterTsCandidate(
                      attempts,
                      attemptIndex,
                    ),
                  );

              if (quickSwitchEligible && selectable.isNotEmpty) {
                AppLogger.info(
                  'PlayerNotifier: Quick audio probe found selectable track(s); staying on current delivery',
                );
              }

              if (quickSwitchEligible && selectable.isEmpty) {
                AppLogger.info(
                  'PlayerNotifier: Quick audio probe found no real tracks; trying .ts delivery before late-audio wait',
                );
                // Reset per-candidate audio indicators so the .ts candidate gets
                // a clean stabilization decision.
                _liveAudioInitialAutoOnly = false;
                _liveAudioHadNoAudioState = false;
                _recordStreamingDiagnostic(
                  phase: StreamingDiagnosticPhase.failure,
                  channel: channel,
                  attempt: attempt,
                  mpvError: state.asData?.value.streamError,
                  duration: DateTime.now().difference(startedAt),
                  deliveryType: effectiveDelivery.diagnosticLabel,
                  diagnosisNote:
                      'Quick audio probe found no real tracks; switching to .ts delivery',
                );
                await _stopLivePlaybackForRetry(current.player, sessionToken);
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                continue;
              }

              // Give healthy proxy/continuous streams more time to expose a real
              // audio track before we stop/reopen and trigger provider reconnects.
              if (selectable.isEmpty && !quickSwitchEligible) {
                if (LiveStreamUrl.isExtensionlessContinuousLiveUrl(
                      attemptPlaybackUri,
                    ) &&
                    !LiveStreamUrl.hasLaterTsCandidate(
                      attempts,
                      attemptIndex,
                    )) {
                  AppLogger.info(
                    'PlayerNotifier: No .ts delivery candidate available; using late-audio wait',
                  );
                }
                final lateWait = await timing.measure(
                  LiveStartupPhase.lateAudio,
                  () => _runLateAudioWait(
                    current.player,
                    sessionToken: sessionToken,
                    delivery: _lastAppliedLiveDelivery ?? effectiveDelivery,
                  ),
                );
                if (lateWait.result == LateAudioWaitResult.cancelled) return;
                selectable = lateWait.selectable;
              }
              if (!_isLiveOpenSessionCurrent(sessionToken)) return;

              rawTracks = current.player.state.tracks.audio;

              String? audioRecoveryNote;

              if (shouldRetryLiveAudioWithAutoDemuxer(
                canSeek: canSeek,
                delivery: effectiveDelivery,
                recoveryAttempted: attemptedRecoveryProfiles.contains(
                  attempt.headerProfile,
                ),
                appliedDemuxerLavfFormat: _lastAppliedDemuxerLavfFormat,
                rawTracks: rawTracks,
                selectableTracks: selectable,
              )) {
                attemptedRecoveryProfiles.add(attempt.headerProfile);
                final previousDemuxer =
                    _lastAppliedDemuxerLavfFormat ?? 'mpegts';
                AppLogger.info(
                  'PlayerNotifier: No real audio tracks detected for live MPEG-TS; retrying with auto demuxer '
                  '(previous demuxer=$previousDemuxer, recovery demuxer=auto, '
                  'rawTracks(${rawTracks.length}): ${LiveAudioTrackService.describeTracks(rawTracks)}, '
                  'selectableTracks(${selectable.length}): ${LiveAudioTrackService.describeTracks(selectable)})',
                );

                AppLogger.info(
                  'PlayerNotifier: Stopping live stream before audio recovery reopen.',
                );
                await _stopLivePlaybackForRetry(current.player, sessionToken);
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;

                final recoveryResult = await timing.measure(
                  LiveStartupPhase.recoveryOpenAndSettle,
                  () async {
                    final opened = await _openStreamInternal(
                      current: current,
                      sourceUrl: url,
                      playbackUrl: attemptPlaybackUri,
                      canSeek: canSeek,
                      startPosition: startPosition,
                      startPaused: startPaused,
                      preBuffer: preBuffer,
                      sessionToken: sessionToken,
                      httpHeaders: attempt.headers,
                      liveStartupBuffer: false,
                      liveDelivery: effectiveDelivery,
                      liveAudioRecovery: true,
                      liveAnalyzeDurationSecondsOverride: PlayerBufferService
                          .liveRecoveryAnalyzeDurationSeconds,
                      liveProbeSizeBytesOverride:
                          PlayerBufferService.liveRecoveryProbeSizeBytes,
                      liveDemuxerLavfFormatOverride: '',
                      openPaused: !canSeek,
                    );
                    if (!opened || !_isLiveOpenSessionCurrent(sessionToken)) {
                      return (opened: opened, settled: false);
                    }
                    final settled = await _waitForStreamSettled(
                      current.player,
                      requirePlaying: false,
                    );
                    return (opened: opened, settled: settled);
                  },
                );
                final recoveryOpened = recoveryResult.opened;
                final recoverySettled = recoveryResult.settled;
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                if (!recoveryOpened) {
                  audioRecoveryNote =
                      'Audio recovery failed: unable to reopen stream with auto demuxer';
                  AppLogger.info('PlayerNotifier: $audioRecoveryNote');
                  lastError = StateError(audioRecoveryNote);
                  lastClassification = StreamDiagnosticsService.classifyFailure(
                    error: lastError,
                    mpvError: state.asData?.value.streamError,
                  );
                  _recordStreamingDiagnostic(
                    phase: StreamingDiagnosticPhase.failure,
                    channel: channel,
                    attempt: attempt,
                    failureKind: lastClassification.kind,
                    mpvError: state.asData?.value.streamError,
                    duration: DateTime.now().difference(startedAt),
                    deliveryType: effectiveDelivery.diagnosticLabel,
                    diagnosisNote: audioRecoveryNote,
                  );
                  await _stopLivePlaybackForRetry(current.player, sessionToken);
                  if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                  continue;
                }

                if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                if (!recoverySettled) {
                  audioRecoveryNote =
                      'Audio recovery failed: stream did not settle after auto demuxer retry';
                  AppLogger.info('PlayerNotifier: $audioRecoveryNote');
                  lastError = TimeoutException(
                    audioRecoveryNote,
                    const Duration(milliseconds: 800),
                  );
                  lastClassification = StreamDiagnosticsService.classifyFailure(
                    error: lastError,
                    mpvError: state.asData?.value.streamError,
                  );
                  _recordStreamingDiagnostic(
                    phase: StreamingDiagnosticPhase.failure,
                    channel: channel,
                    attempt: attempt,
                    failureKind: lastClassification.kind,
                    mpvError: state.asData?.value.streamError,
                    duration: DateTime.now().difference(startedAt),
                    deliveryType: effectiveDelivery.diagnosticLabel,
                    diagnosisNote: audioRecoveryNote,
                  );
                  await _stopLivePlaybackForRetry(current.player, sessionToken);
                  if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                  continue;
                }

                selectable = await timing.measure(
                  LiveStartupPhase.recoveryTracks,
                  () async {
                    var recovered =
                        await LiveAudioTrackService.waitForSelectableTracks(
                          current.player,
                          timeout: liveTrackWaitTimeoutForAnalyzeSeconds(
                            PlayerBufferService
                                .liveRecoveryAnalyzeDurationSeconds,
                          ),
                          onProgress: (tracks, selectableTracks) {
                            if (!_isLiveOpenSessionCurrent(sessionToken)) {
                              return;
                            }
                            if (selectableTracks.isEmpty) {
                              _liveAudioHadNoAudioState = true;
                            } else {
                              _liveAudioInitialAutoOnly = false;
                            }
                            unawaited(
                              _logAudioDiagnosticsSnapshotAsync(
                                player: current.player,
                                stage: 'audio recovery poll',
                                rawTracks: tracks.audio,
                                selectableTracks: selectableTracks,
                                delivery:
                                    _lastAppliedLiveDelivery ??
                                    effectiveDelivery,
                              ),
                            );
                          },
                        );
                    if (recovered.isEmpty) {
                      final lateWait = await _runLateAudioWait(
                        current.player,
                        sessionToken: sessionToken,
                        delivery: _lastAppliedLiveDelivery ?? effectiveDelivery,
                      );
                      if (lateWait.result == LateAudioWaitResult.cancelled) {
                        return const <AudioTrack>[];
                      }
                      recovered = lateWait.selectable;
                    }
                    return recovered;
                  },
                );
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;

                rawTracks = current.player.state.tracks.audio;
                final recoveryBest = LiveAudioTrackService.pickBestFrom(
                  selectable,
                  preferStereo: _forceStereoEnabled,
                  preferredLanguage: _preferredAudioLanguage,
                );
                if (shouldContinueLiveFallbackAfterAudioRecovery(
                  canSeek: canSeek,
                  recoveryAttempted: attemptedRecoveryProfiles.contains(
                    attempt.headerProfile,
                  ),
                  rawTracks: rawTracks,
                  selectableTracks: selectable,
                )) {
                  audioRecoveryNote =
                      'No real audio after recovery; trying next fallback/header profile';
                  liveAudioFallbackNeedsHeaderProfileRetryLog = true;
                  liveAudioRecoveryFallbackFailed = true;
                  AppLogger.info(
                    'PlayerNotifier: $audioRecoveryNote '
                    '(rawTracks(${rawTracks.length}): ${LiveAudioTrackService.describeTracks(rawTracks)}, '
                    'selectableTracks(${selectable.length}): ${LiveAudioTrackService.describeTracks(selectable)})',
                  );
                  lastError = StateError(audioRecoveryNote);
                  lastClassification = StreamDiagnosticsService.classifyFailure(
                    error: lastError,
                    mpvError: state.asData?.value.streamError,
                  );
                  _recordStreamingDiagnostic(
                    phase: StreamingDiagnosticPhase.failure,
                    channel: channel,
                    attempt: attempt,
                    failureKind: lastClassification.kind,
                    mpvError: state.asData?.value.streamError,
                    duration: DateTime.now().difference(startedAt),
                    deliveryType: effectiveDelivery.diagnosticLabel,
                    diagnosisNote:
                        '$audioRecoveryNote | rawTracks(${rawTracks.length}) / selectableTracks(${selectable.length})',
                  );
                  AppLogger.info(
                    'PlayerNotifier: Stopping live stream before next fallback attempt.',
                  );
                  await _stopLivePlaybackForRetry(current.player, sessionToken);
                  if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                  continue;
                } else {
                  final exposedTrack = recoveryBest ?? selectable.first;
                  audioRecoveryNote =
                      'Audio recovered via ${attempt.headerProfile.label}: ${LiveAudioTrackService.labelFor(exposedTrack)}';
                  AppLogger.info('PlayerNotifier: $audioRecoveryNote');
                }
              }

              if (rawTracks.isEmpty) {
                AppLogger.info(
                  'PlayerNotifier: No raw audio tracks detected by MPV after timeout.',
                );
              } else if (selectable.isEmpty && audioRecoveryNote == null) {
                AppLogger.info(
                  'PlayerNotifier: MPV exposed raw audio tracks, but none were selectable.',
                );
              }

              if (shouldContinueLiveFallbackWhenNoRealAudio(
                canSeek: canSeek,
                rawTracks: rawTracks,
                selectableTracks: selectable,
              )) {
                audioRecoveryNote =
                    'No real audio exposed after startup; trying next fallback/header profile';
                liveAudioFallbackNeedsHeaderProfileRetryLog = true;
                liveAudioRecoveryFallbackFailed = true;
                AppLogger.info(
                  'PlayerNotifier: $audioRecoveryNote '
                  '(rawTracks(${rawTracks.length}): ${LiveAudioTrackService.describeTracks(rawTracks)}, '
                  'selectableTracks(${selectable.length}): ${LiveAudioTrackService.describeTracks(selectable)})',
                );
                lastError = StateError(audioRecoveryNote);
                lastClassification = StreamDiagnosticsService.classifyFailure(
                  error: lastError,
                  mpvError: state.asData?.value.streamError,
                );
                _recordStreamingDiagnostic(
                  phase: StreamingDiagnosticPhase.failure,
                  channel: channel,
                  attempt: attempt,
                  failureKind: lastClassification.kind,
                  mpvError: state.asData?.value.streamError,
                  duration: DateTime.now().difference(startedAt),
                  deliveryType: effectiveDelivery.diagnosticLabel,
                  diagnosisNote:
                      '$audioRecoveryNote | rawTracks(${rawTracks.length}) / selectableTracks(${selectable.length})',
                );
                await _stopLivePlaybackForRetry(current.player, sessionToken);
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                continue;
              }

              unawaited(
                _logAudioDiagnosticsSnapshotAsync(
                  player: current.player,
                  stage: 'startup settled',
                  rawTracks: rawTracks,
                  selectableTracks: selectable,
                  delivery: _lastAppliedLiveDelivery ?? effectiveDelivery,
                ),
              );

              _update(
                (s) => s.copyWith(
                  audioTracks: selectable,
                  clearSelectedAudioTrackId: true,
                ),
              );
              final signature = _audioTrackSignature(rawTracks);
              if (_lastAudioTrackSignature != signature) {
                _lastAudioTrackSignature = signature;
                if (selectable.isEmpty) {
                  AppLogger.info(
                    'PlayerNotifier: No selectable audio tracks detected yet.',
                  );
                } else {
                  AppLogger.info(
                    'PlayerNotifier: Detected ${selectable.length} selectable audio track(s).',
                  );
                }
              }

              final finalizationResult =
                  await finalizePreparedLiveCandidatePlayback(
                    shouldAutoSelectAudioTrack:
                        selectable.isNotEmpty && _manualAudioTrackId == null,
                    shouldEvaluateAudioDecode: selectable.isNotEmpty,
                    applyBestTrack: () async {
                      if (selectable.isNotEmpty &&
                          _manualAudioTrackId == null) {
                        await LiveAudioTrackService.applyBestTrack(
                          current.player,
                          tracks: selectable,
                          preferStereo: _forceStereoEnabled,
                          preferredLanguage: _preferredAudioLanguage,
                        );
                        _liveAudioSelectedTrackId =
                            current.player.state.track.audio.id;
                      }
                    },
                    classifyDecodedAudio: () {
                      return timing.measure(
                        LiveStartupPhase.decodeConfirmation,
                        () => _classifyDecodedAudioAfterTrackSelection(
                          current.player,
                          selectableTracks: selectable,
                          stage: 'startup settled',
                          attemptStartedAt: startedAt,
                        ),
                      );
                    },
                    releasePlayback: (decodeDecision) =>
                        _releasePreparedLivePlayback(
                          current.player,
                          sessionToken: sessionToken,
                          liveStartupBufferEnabled: liveStartupBufferEnabled,
                          liveStartupBufferSeconds: liveStartupBufferSeconds,
                          channel: channel,
                          attempt: attempt,
                          deliveryType: effectiveDelivery.diagnosticLabel,
                          audioRecoveryWasNeeded: audioRecoveryNote != null,
                          liveAudioInitialAutoOnly: _liveAudioInitialAutoOnly,
                          liveAudioHadNoAudioState: _liveAudioHadNoAudioState,
                          liveAudioTrackSwitchedDuringPrep:
                              _liveAudioTrackSwitchedDuringPrep,
                          timing: timing,
                          successOutcome: LiveStartupOutcome.success,
                          attemptStartedAt: startedAt,
                          decodeDecision: decodeDecision,
                        ),
                  );

              if (finalizationResult ==
                  LivePlaybackFinalizationResult.decodeFailed) {
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                audioRecoveryNote =
                    'Audio track exposed but decoding failed; trying next fallback/header profile';
                liveAudioFallbackNeedsHeaderProfileRetryLog = true;
                liveAudioRecoveryFallbackFailed = true;
                AppLogger.info('PlayerNotifier: $audioRecoveryNote');
                lastError = StateError(audioRecoveryNote);
                lastClassification = StreamDiagnosticsService.classifyFailure(
                  error: lastError,
                  mpvError: state.asData?.value.streamError,
                );
                _recordStreamingDiagnostic(
                  phase: StreamingDiagnosticPhase.failure,
                  channel: channel,
                  attempt: attempt,
                  failureKind: lastClassification.kind,
                  mpvError: state.asData?.value.streamError,
                  duration: DateTime.now().difference(startedAt),
                  deliveryType: effectiveDelivery.diagnosticLabel,
                  diagnosisNote: audioRecoveryNote,
                );
                await _stopLivePlaybackForRetry(current.player, sessionToken);
                if (!_isLiveOpenSessionCurrent(sessionToken)) return;
                continue;
              }

              if (finalizationResult ==
                  LivePlaybackFinalizationResult.staleSession) {
                return;
              }

              final diagnosisNotes = <String>[
                if (probe?.hlsHintSummary != null)
                  'HLS probe: ${probe!.hlsHintSummary}',
                if (probe?.looksLikeHls == true &&
                    probe?.hlsHintSummary == null)
                  'HLS probe detected',
                ?audioRecoveryNote,
              ];

              _recordStreamingDiagnostic(
                phase: StreamingDiagnosticPhase.success,
                channel: channel,
                attempt: attempt,
                deliveryType: effectiveDelivery.diagnosticLabel,
                duration: DateTime.now().difference(startedAt),
                diagnosisNote: diagnosisNotes.isEmpty
                    ? null
                    : diagnosisNotes.join(' | '),
              );
              return;
            }
            lastError = TimeoutException(
              'Live stream did not settle in time: ${redactStreamUrl(attemptPlaybackUri)}',
              const Duration(milliseconds: 800),
            );
            lastClassification = StreamDiagnosticsService.classifyFailure(
              error: lastError,
              mpvError: state.asData?.value.streamError,
            );
            _recordStreamingDiagnostic(
              phase: StreamingDiagnosticPhase.failure,
              channel: channel,
              attempt: attempt,
              failureKind: lastClassification.kind,
              mpvError: state.asData?.value.streamError,
              duration: DateTime.now().difference(startedAt),
              deliveryType: effectiveDelivery.diagnosticLabel,
              diagnosisNote: probe?.hlsHintSummary != null
                  ? '${lastClassification.label} | ${probe!.hlsHintSummary}'
                  : (probe?.looksLikeHls == true
                        ? '${lastClassification.label} | HLS probe detected'
                        : lastClassification.label),
            );

            if (settings.showOnErrorEnabled) {
              _logStreamingFailureToUi(
                '${attempt.label} timed out (${lastClassification.label}).',
              );
            }

            AppLogger.info(
              'PlayerNotifier: Live URL timed out (${redactStreamUrl(attemptPlaybackUri)}) — trying next format.',
            );
          } catch (e) {
            if (!_isLiveOpenSessionCurrent(sessionToken)) return;
            lastError = e;
            lastClassification = StreamDiagnosticsService.classifyFailure(
              error: e,
              mpvError: state.asData?.value.streamError,
            );
            _recordStreamingDiagnostic(
              phase: StreamingDiagnosticPhase.failure,
              channel: channel,
              attempt: attempt,
              failureKind: lastClassification.kind,
              mpvError: state.asData?.value.streamError,
              duration: DateTime.now().difference(startedAt),
              deliveryType: effectiveDelivery.diagnosticLabel,
              diagnosisNote: probe?.hlsHintSummary != null
                  ? '${lastClassification.label} | ${probe!.hlsHintSummary}'
                  : (probe?.looksLikeHls == true
                        ? '${lastClassification.label} | HLS probe detected'
                        : lastClassification.label),
            );

            if (settings.showOnErrorEnabled) {
              _logStreamingFailureToUi(
                '${attempt.label} failed (${lastClassification.label}).',
              );
            }

            AppLogger.info(
              'PlayerNotifier: Live URL failed (${redactStreamUrl(attemptPlaybackUri)}) — trying next format.',
            );
          }

          if (!_isLiveOpenSessionCurrent(sessionToken)) return;
          await _stopLivePlaybackForRetry(current.player, sessionToken);
          if (!_isLiveOpenSessionCurrent(sessionToken)) return;
        }

        // All candidates failed solely because no audio was exposed — play the
        // first candidate video-only instead of erroring out. The tracks-stream
        // listener in build() adopts late audio tracks automatically.
        if (liveAudioRecoveryFallbackFailed && attempts.isNotEmpty) {
          final bestEffortAttempt = attempts.first;
          final bestEffortDelivery = LiveStreamUrl.deliveryFor(
            bestEffortAttempt.playbackUrl,
            looksLikeHls: bestEffortAttempt.playbackUrl == sourcePlaybackUrl
                ? hlsProbeResult?.looksLikeHls
                : null,
          );
          timing.recordCandidate(
            attemptLabel: bestEffortAttempt.label,
            headerProfile: bestEffortAttempt.headerProfile.label,
            delivery: bestEffortDelivery.diagnosticLabel,
          );
          final bestEffortStartedAt = DateTime.now();
          try {
            final bestEffortResult = await timing.measure(
              LiveStartupPhase.openAndSettle,
              () async {
                final opened = await _openStreamInternal(
                  current: current,
                  sourceUrl: url,
                  playbackUrl: bestEffortAttempt.playbackUrl,
                  canSeek: canSeek,
                  startPosition: startPosition,
                  startPaused: startPaused,
                  preBuffer: preBuffer,
                  sessionToken: sessionToken,
                  httpHeaders: bestEffortAttempt.headers,
                  liveStartupBuffer: false,
                  liveDelivery: bestEffortDelivery,
                  openPaused: !canSeek,
                );
                if (!opened || !_isLiveOpenSessionCurrent(sessionToken)) {
                  return (opened: opened, settled: false);
                }
                final settled = await _waitForStreamSettled(
                  current.player,
                  requirePlaying: false,
                );
                return (opened: opened, settled: settled);
              },
            );
            final opened = bestEffortResult.opened;
            final settled = bestEffortResult.settled;
            if (!_isLiveOpenSessionCurrent(sessionToken)) return;
            if (opened) {
              if (!_isLiveOpenSessionCurrent(sessionToken)) return;
              if (settled) {
                final bestEffortRelease = await _releasePreparedLivePlayback(
                  current.player,
                  sessionToken: sessionToken,
                  liveStartupBufferEnabled: liveStartupBufferEnabled,
                  liveStartupBufferSeconds: liveStartupBufferSeconds,
                  channel: channel,
                  attempt: bestEffortAttempt,
                  deliveryType: bestEffortDelivery.diagnosticLabel,
                  audioRecoveryWasNeeded: true,
                  liveAudioInitialAutoOnly: _liveAudioInitialAutoOnly,
                  liveAudioHadNoAudioState: _liveAudioHadNoAudioState,
                  liveAudioTrackSwitchedDuringPrep:
                      _liveAudioTrackSwitchedDuringPrep,
                  timing: timing,
                  successOutcome: LiveStartupOutcome.bestEffortSuccess,
                  attemptStartedAt: bestEffortStartedAt,
                );
                if (bestEffortRelease !=
                    LivePlaybackFinalizationResult.released) {
                  return;
                }

                const note =
                    'Best-effort video-only playback; waiting for late audio tracks';
                AppLogger.info('PlayerNotifier: $note');
                _logAudioWarningToUi(
                  'Keine Audiospur erkannt – Wiedergabe ohne Ton gestartet, '
                  'Ton wird automatisch übernommen sobald erkannt',
                );
                _recordStreamingDiagnostic(
                  phase: StreamingDiagnosticPhase.success,
                  channel: channel,
                  attempt: bestEffortAttempt,
                  deliveryType: bestEffortDelivery.diagnosticLabel,
                  duration: DateTime.now().difference(bestEffortStartedAt),
                  diagnosisNote: note,
                );
                // Watchdog: the tracks listener may auto-select an undecodable
                // track (PMT codec mismatch) which would freeze video on A/V sync.
                unawaited(
                  _guardLiveAudioAfterOpen(
                    current.player,
                    sessionToken: sessionToken,
                    openedAt: bestEffortStartedAt,
                  ),
                );
                return;
              }
            }
          } catch (e) {
            if (!_isLiveOpenSessionCurrent(sessionToken)) return;
            AppLogger.info(
              'PlayerNotifier: Best-effort video-only open failed: ${redactStreamText(e.toString())}',
            );
          }
          if (!_isLiveOpenSessionCurrent(sessionToken)) return;
        }

        final failure =
            lastError ??
            StateError(
              'Live stream failed to open with ${attempts.length} URL format(s).',
            );
        final message = redactStreamText(failure.toString());
        if (settings.showOnErrorEnabled) {
          _logStreamingFailureToUi(
            'Live stream failed after ${attempts.length} attempt(s): ${lastClassification?.label ?? 'unknown'}.',
          );
        }
        AppLogger.error(
          liveAudioRecoveryFallbackFailed
              ? 'PlayerNotifier: All live candidates failed to expose real audio'
              : 'PlayerNotifier: All live URL candidates failed',
          redactStreamText(message),
        );
        _update(
          (s) => s.copyWith(
            streamError: message,
            isBuffering: false,
            isLiveStartupBuffering: false,
          ),
        );
        timing.finish(LiveStartupOutcome.finalError);
        return;
      } finally {
        if (!timing.isFinished) {
          timing.finish(
            _isLiveOpenSessionCurrent(sessionToken)
                ? LiveStartupOutcome.finalError
                : LiveStartupOutcome.sessionAborted,
            abortReason: _isLiveOpenSessionCurrent(sessionToken)
                ? null
                : 'session-replaced',
          );
        }
      }
    }

    await _openStreamInternal(
      current: current,
      sourceUrl: url,
      playbackUrl: url,
      canSeek: canSeek,
      sessionToken: sessionToken,
      httpHeaders: canSeek ? kVodStreamHttpHeaders : kLiveStreamHttpHeaders,
      startPosition: startPosition,
      startPaused: startPaused,
      preBuffer: preBuffer,
    );
  }

  /// Opens a stream and optionally keeps live playback paused until the
  /// caller decides the candidate is ready to be released.
  Future<bool> _openStreamInternal({
    required PlayerState current,
    required String sourceUrl,

    // ignore: unused_element_parameter — kept for future telemetry of original DB URL.
    required String playbackUrl,
    required bool canSeek,
    required int sessionToken,
    required Map<String, String> httpHeaders,
    LiveStreamDelivery? liveDelivery,
    bool liveAudioRecovery = false,
    int? liveAnalyzeDurationSecondsOverride,
    int? liveProbeSizeBytesOverride,
    String? liveDemuxerLavfFormatOverride,
    Duration? startPosition,
    bool startPaused = false,
    bool preBuffer = false,
    bool liveStartupBuffer = false,
    bool openPaused = false,
  }) async {
    try {
      AppLogger.info(
        'PlayerNotifier: Opening stream — ${redactStreamUrl(playbackUrl)}',
      );

      if (canSeek) {
        resetVodMainVideoSurfaceReady(ref);
      }
      _invalidateVideoController();
      _lastSuccessfulOpenAt = null;

      final bufferSeconds =
          ref.read(playerBufferSecondsProvider).valueOrNull ??
          PlayerBufferSecondsNotifier.defaultSeconds;
      final effectiveDelivery = canSeek
          ? LiveStreamDelivery.continuous
          : (liveDelivery ?? LiveStreamUrl.deliveryFor(playbackUrl));

      await PlayerBufferService.applyPlaybackProfile(
        current.player,
        isLive: !canSeek,
        preloadSeconds: bufferSeconds,
        liveDelivery: effectiveDelivery,
        liveStartupBuffer: !canSeek && liveStartupBuffer,
        vodAggressivePreload: canSeek && preBuffer,
        liveAnalyzeDurationSecondsOverride: liveAnalyzeDurationSecondsOverride,
        liveProbeSizeBytesOverride: liveProbeSizeBytesOverride,
        liveDemuxerLavfFormatOverride: liveDemuxerLavfFormatOverride,
      );
      await _applyAudioCompatibility(current.player);
      _lastAppliedLiveDelivery = effectiveDelivery;
      final appliedDemuxerLavfFormat =
          liveDemuxerLavfFormatOverride ??
          PlayerBufferService.demuxerLavfFormatForDelivery(effectiveDelivery);
      _lastAppliedDemuxerLavfFormat = appliedDemuxerLavfFormat.isEmpty
          ? (liveAudioRecovery ? 'auto' : 'cleared')
          : appliedDemuxerLavfFormat;

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      state = AsyncData(
        current.copyWith(
          clearStreamError: true,
          isPlaying: false,
          isBuffering: true,
          isLiveStartupBuffering: !canSeek && liveStartupBuffer,
          position: Duration.zero,
          duration: Duration.zero,
          bufferDuration: Duration.zero,
          audioTracks: const [],
          clearSelectedAudioTrackId: true,
          vodForwardBufferMs: 0,
          playbackUri: playbackUrl,
          clearMediaInfo: true,
          mediaInfo: PlaybackMediaInfo(playbackUri: playbackUrl),
        ),
      );

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      await current.player.open(
        Media(
          playbackUrl,
          httpHeaders: canSeek ? kVodStreamHttpHeaders : httpHeaders,
        ),
        play: !openPaused,
      );
      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }
      _lastSuccessfulOpenAt = DateTime.now();

      if (canSeek && startPosition != null && startPosition > Duration.zero) {
        try {
          await current.player.seek(startPosition);
        } catch (e) {
          AppLogger.info('PlayerNotifier: Resume seek skipped: $e');
        }
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      final holdPaused = canSeek && (startPaused || preBuffer);
      if (holdPaused) {
        await current.player.pause();
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      if (canSeek && preBuffer) {
        await _waitForVodPreBuffer(current.player, sessionToken: sessionToken);
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      if (canSeek) {
        await PlayerBufferService.applyVodPlaybackProfile(
          current.player,
          preloadSeconds: bufferSeconds,
          aggressivePreload: preBuffer,
        );
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      if (!holdPaused && !openPaused) {
        await current.player.play();
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        return false;
      }

      AppLogger.info('PlayerNotifier: Stream opened successfully.');
      return true;
    } catch (e, stackTrace) {
      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        AppLogger.info(
          'PlayerNotifier: Ignoring stale live open failure for ${redactStreamUrl(playbackUrl)}.',
        );
        return false;
      }

      AppLogger.error(
        'PlayerNotifier: Failed to open stream',
        redactStreamText(e.toString()),
        stackTrace,
      );

      final updated = state.asData?.value ?? current;

      state = AsyncData(
        updated.copyWith(
          streamError: redactStreamText(e.toString()),
          isLiveStartupBuffering: false,
        ),
      );

      rethrow;
    }
  }

  Future<LiveAudioDecodeDecision> _classifyDecodedAudioAfterTrackSelection(
    Player player, {
    required List<AudioTrack> selectableTracks,
    required String stage,
    required DateTime attemptStartedAt,
  }) async {
    final mediaInfo = state.asData?.value.mediaInfo ?? PlaybackMediaInfo.empty;
    final hadDecodeWarning =
        _lastAudioWarningAt != null &&
        !_lastAudioWarningAt!.isBefore(attemptStartedAt);
    final decision = classifyLiveAudioDecodeDecision(
      hasRealAudioTrack: selectableTracks.isNotEmpty,
      hasDecodedAudioInfo: mediaInfo.hasAudioInfo,
      hadDecodeWarning: hadDecodeWarning,
    );
    final selectedTrack = player.state.track.audio;
    final selectedLabel = LiveAudioTrackService.diagnosticLabelFor(
      selectedTrack,
    );

    switch (decision) {
      case LiveAudioDecodeDecision.confirmed:
        AppLogger.info(
          'PlayerNotifier: Decoded audio parameters already available after track selection '
          '(${_diagnosticsReporter.audioParamsLabel(mediaInfo)}, '
          'bitrate=${_diagnosticsReporter.audioBitrateLabel(mediaInfo)}).',
        );
        final compatibilityHint = decodedAudioCompatibilityHint(mediaInfo);
        if (compatibilityHint != null) {
          AppLogger.info('PlayerNotifier: $compatibilityHint');
        }
      case LiveAudioDecodeDecision.provisional:
        AppLogger.info(
          'PlayerNotifier: Audio track selected provisionally; decoded parameters '
          'will be checked during warm-up ($stage, $selectedLabel).',
        );
      case LiveAudioDecodeDecision.failed:
        final message =
            'Audio track selected but a decode warning occurred before release ($stage, $selectedLabel).';
        AppLogger.warning('PlayerNotifier: $message');
        _logAudioWarningToUi(message);
    }
    return decision;
  }

  /// Wraps [waitForLateLiveAudioTracks] with the awaiting UI flag.
  ///
  /// Returns the unchanged/selectable tracks immediately if the candidate is
  /// not eligible; otherwise it keeps the stream open, shows the non-blocking
  /// "Audio wird erkannt" overlay, and waits for a real audio track.
  Future<({LateAudioWaitResult result, List<AudioTrack> selectable})>
  _runLateAudioWait(
    Player player, {
    required int sessionToken,
    required LiveStreamDelivery delivery,
  }) async {
    _update((s) => s.copyWith(isLiveAudioAwaiting: true));
    try {
      return await waitForLateLiveAudioTracks(
        delivery: delivery,
        currentTracks: () => player.state.tracks,
        isSessionCurrent: () => _isLiveOpenSessionCurrent(sessionToken),
        hasStreamError: () => state.asData?.value.streamError != null,
        timeout: _lateAudioWaitTimeout,
        pollInterval: _lateAudioWaitPollInterval,
      );
    } finally {
      _update((s) => s.copyWith(isLiveAudioAwaiting: false));
    }
  }

  static const _liveAudioStabilizationWindow = Duration(milliseconds: 600);
  static const _liveAudioStabilizationTimeout = Duration(seconds: 3);
  static const _liveAudioStabilizationPollInterval = Duration(milliseconds: 50);

  bool _hasDecodedAudioInfo() {
    return state.asData?.value.mediaInfo.hasAudioInfo ?? false;
  }

  /// Decides whether the live release path should enter the audio stabilization
  /// gate. The gate is intentionally narrow: normal channels with a real track
  /// skip it unless a concrete late-audio risk indicator is present.
  ///
  /// Risk indicators:
  /// - audio recovery / fallback was needed
  /// - initially only auto/no tracks were exposed and a real track came later
  /// - the selected track switched during preparation
  /// - the stream had a no-audio state during this open attempt
  /// - container is known to expose late audio (raw MPEG-TS direct) and audio
  ///   params are still missing
  static bool shouldWaitForLiveAudioStabilization({
    required bool hasDecodedAudioInfo,
    required bool audioRecoveryWasNeeded,
    required bool liveAudioInitialAutoOnly,
    required bool liveAudioHadNoAudioState,
    required bool liveAudioTrackSwitchedDuringPrep,
    required bool isDirectMpegTs,
  }) {
    return LiveAudioStabilizationPolicy.shouldWait(
      hasDecodedAudioInfo: hasDecodedAudioInfo,
      audioRecoveryWasNeeded: audioRecoveryWasNeeded,
      initialAutoOnly: liveAudioInitialAutoOnly,
      hadNoAudioState: liveAudioHadNoAudioState,
      trackSwitchedDuringPrep: liveAudioTrackSwitchedDuringPrep,
      isDirectMpegTs: isDirectMpegTs,
    );
  }

  static String _stabilizationReason({
    required bool hasDecodedAudioInfo,
    required bool audioRecoveryWasNeeded,
    required bool liveAudioInitialAutoOnly,
    required bool liveAudioHadNoAudioState,
    required bool liveAudioTrackSwitchedDuringPrep,
    required bool isDirectMpegTs,
  }) {
    return LiveAudioStabilizationPolicy.reason(
      hasDecodedAudioInfo: hasDecodedAudioInfo,
      audioRecoveryWasNeeded: audioRecoveryWasNeeded,
      initialAutoOnly: liveAudioInitialAutoOnly,
      hadNoAudioState: liveAudioHadNoAudioState,
      trackSwitchedDuringPrep: liveAudioTrackSwitchedDuringPrep,
      isDirectMpegTs: isDirectMpegTs,
    );
  }

  /// Holds live playback back briefly after audio becomes available to mask the
  /// mpv audio reconfiguration freeze / doubletime catch-up moment.
  ///
  /// Returns `true` when the gate completes (stabilized or timed out) and the
  /// caller may continue. Returns `false` only when the session became stale.
  Future<bool> _waitForLiveAudioStabilization(
    Player player, {
    required int sessionToken,
    required bool audioRecoveryWasNeeded,
    required bool liveAudioInitialAutoOnly,
    required bool liveAudioHadNoAudioState,
    required bool liveAudioTrackSwitchedDuringPrep,
    required bool isDirectMpegTs,
  }) async {
    if (!_isLiveOpenSessionCurrent(sessionToken)) return false;

    final hasAudioInfo = _hasDecodedAudioInfo();
    final needsStabilization = shouldWaitForLiveAudioStabilization(
      hasDecodedAudioInfo: hasAudioInfo,
      audioRecoveryWasNeeded: audioRecoveryWasNeeded,
      liveAudioInitialAutoOnly: liveAudioInitialAutoOnly,
      liveAudioHadNoAudioState: liveAudioHadNoAudioState,
      liveAudioTrackSwitchedDuringPrep: liveAudioTrackSwitchedDuringPrep,
      isDirectMpegTs: isDirectMpegTs,
    );
    if (!needsStabilization) {
      AppLogger.info(
        'PlayerNotifier: Audio stabilization gate skipped (stable track fast path).',
      );
      return true;
    }

    final reason = _stabilizationReason(
      hasDecodedAudioInfo: hasAudioInfo,
      audioRecoveryWasNeeded: audioRecoveryWasNeeded,
      liveAudioInitialAutoOnly: liveAudioInitialAutoOnly,
      liveAudioHadNoAudioState: liveAudioHadNoAudioState,
      liveAudioTrackSwitchedDuringPrep: liveAudioTrackSwitchedDuringPrep,
      isDirectMpegTs: isDirectMpegTs,
    );

    _update((s) => s.copyWith(isLiveAudioStabilizing: true));
    AppLogger.info(
      'PlayerNotifier: Audio stabilization gate started (reason: $reason).',
    );

    final startedAt = DateTime.now();
    DateTime? paramsObservedAt;
    if (hasAudioInfo) {
      paramsObservedAt = DateTime.now();
    }

    while (DateTime.now().difference(startedAt) <
        _liveAudioStabilizationTimeout) {
      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        _update((s) => s.copyWith(isLiveAudioStabilizing: false));
        return false;
      }

      final currentHasAudioInfo = _hasDecodedAudioInfo();
      if (currentHasAudioInfo) {
        paramsObservedAt ??= DateTime.now();
        final heldFor = DateTime.now().difference(paramsObservedAt);
        if (heldFor >= _liveAudioStabilizationWindow) {
          AppLogger.info(
            'PlayerNotifier: Audio stabilization gate released '
            '(reason: $reason, held ${heldFor.inMilliseconds}ms).',
          );
          _update((s) => s.copyWith(isLiveAudioStabilizing: false));
          return true;
        }
      } else {
        // Audio params dropped again; reset the observation timer so we only
        // release after a contiguous stable window.
        paramsObservedAt = null;
      }

      await Future<void>.delayed(_liveAudioStabilizationPollInterval);
    }

    if (!_isLiveOpenSessionCurrent(sessionToken)) {
      _update((s) => s.copyWith(isLiveAudioStabilizing: false));
      return false;
    }

    AppLogger.warning(
      'PlayerNotifier: Audio stabilization gate timed out (reason: $reason); releasing anyway.',
    );
    _update((s) => s.copyWith(isLiveAudioStabilizing: false));
    return true;
  }

  /// Post-release watchdog: if an auto-selected track later fails to decode,
  /// deselect audio so A/V sync does not freeze visible video and prevent the
  /// tracks listener from immediately re-selecting the broken track.
  Future<void> _guardLiveAudioAfterOpen(
    Player player, {
    required int sessionToken,
    required DateTime openedAt,
  }) async {
    const pollInterval = Duration(milliseconds: 250);
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < _bestEffortAudioWatchWindow) {
      if (!_isLiveOpenSessionCurrent(sessionToken)) return;

      final selectable = LiveAudioTrackService.selectableTracks(
        player.state.tracks,
      );
      final mediaInfo =
          state.asData?.value.mediaInfo ?? PlaybackMediaInfo.empty;

      if (selectable.isNotEmpty && mediaInfo.hasAudioInfo) return;

      final hadDecodeWarning =
          _lastAudioWarningAt != null &&
          !_lastAudioWarningAt!.isBefore(openedAt);
      if (selectable.isNotEmpty &&
          hadDecodeWarning &&
          !mediaInfo.hasAudioInfo) {
        _audioDisabledByWatchdog = true;
        try {
          await player.setAudioTrack(AudioTrack.no());
        } catch (e) {
          AppLogger.info(
            'PlayerNotifier: Disabling undecodable audio track failed: $e',
          );
        }
        const message =
            'Audiospur nicht dekodierbar (PMT codec mismatch) – Wiedergabe ohne Ton';
        AppLogger.info('PlayerNotifier: $message');
        _logAudioWarningToUi(message);
        return;
      }

      await Future<void>.delayed(pollInterval);
    }
  }

  Future<LivePlaybackFinalizationResult> _releasePreparedLivePlayback(
    Player player, {
    required int sessionToken,
    required bool liveStartupBufferEnabled,
    required int liveStartupBufferSeconds,
    required Channel? channel,
    required StreamingFallbackAttempt attempt,
    required String? deliveryType,
    required bool audioRecoveryWasNeeded,
    required bool liveAudioInitialAutoOnly,
    required bool liveAudioHadNoAudioState,
    required bool liveAudioTrackSwitchedDuringPrep,
    required LiveStartupTiming timing,
    required LiveStartupOutcome successOutcome,
    required DateTime attemptStartedAt,
    LiveAudioDecodeDecision? decodeDecision,
  }) async {
    if (!_isLiveOpenSessionCurrent(sessionToken)) {
      return LivePlaybackFinalizationResult.staleSession;
    }

    // Best-effort keeps its established paused stabilization behavior. Regular
    // candidates instead warm up only after play(), under the preparation
    // overlay, because many streams expose decoded parameters only then.
    if (decodeDecision == null) {
      final isDirectMpegTs =
          _lastAppliedLiveDelivery == LiveStreamDelivery.continuous &&
          (_lastAppliedDemuxerLavfFormat == 'mpegts' ||
              _lastAppliedDemuxerLavfFormat == null);

      final stabilized = await timing.measure(
        LiveStartupPhase.stabilization,
        () => _waitForLiveAudioStabilization(
          player,
          sessionToken: sessionToken,
          audioRecoveryWasNeeded: audioRecoveryWasNeeded,
          liveAudioInitialAutoOnly: liveAudioInitialAutoOnly,
          liveAudioHadNoAudioState: liveAudioHadNoAudioState,
          liveAudioTrackSwitchedDuringPrep: liveAudioTrackSwitchedDuringPrep,
          isDirectMpegTs: isDirectMpegTs,
        ),
      );
      if (!stabilized || !_isLiveOpenSessionCurrent(sessionToken)) {
        return LivePlaybackFinalizationResult.staleSession;
      }
    }

    if (liveStartupBufferEnabled) {
      _update((s) => s.copyWith(isLiveStartupBuffering: true));
      final bufferReady = await timing.measure(
        LiveStartupPhase.startupBuffer,
        () async {
          await PlayerBufferService.applyPlaybackProfile(
            player,
            isLive: true,
            preloadSeconds: liveStartupBufferSeconds,
            liveDelivery:
                _lastAppliedLiveDelivery ?? LiveStreamDelivery.continuous,
            liveStartupBuffer: true,
          );
          if (!_isLiveOpenSessionCurrent(sessionToken)) {
            _update((s) => s.copyWith(isLiveStartupBuffering: false));
            return false;
          }
          return _waitForLiveStartupBuffer(
            player,
            sessionToken,
            liveStartupBufferSeconds,
            channel: channel,
            attempt: attempt,
            deliveryType: deliveryType,
          );
        },
      );

      if (!bufferReady) {
        // Cancellation already reset the flag; timeout falls through to the
        // release below so the user still gets playback after waiting.
        if (!_isLiveOpenSessionCurrent(sessionToken)) {
          return LivePlaybackFinalizationResult.staleSession;
        }
      }

      if (!_isLiveOpenSessionCurrent(sessionToken)) {
        _update((s) => s.copyWith(isLiveStartupBuffering: false));
        return LivePlaybackFinalizationResult.staleSession;
      }
    } else {
      AppLogger.info('PlayerNotifier: Live startup buffer skipped (off)');
    }

    AppLogger.info(
      liveStartupBufferEnabled
          ? 'PlayerNotifier: Live candidate prepared; releasing playback after startup buffer.'
          : 'PlayerNotifier: Live candidate prepared; releasing playback.',
    );

    if (decodeDecision == null) {
      final released = await finishLiveStartupAfterPlay(
        timing: timing,
        successOutcome: successOutcome,
        isSessionCurrent: () => _isLiveOpenSessionCurrent(sessionToken),
        play: player.play,
      );
      if (!released) return LivePlaybackFinalizationResult.staleSession;
      if (liveStartupBufferEnabled) {
        _update((s) => s.copyWith(isLiveStartupBuffering: false));
      }
      return LivePlaybackFinalizationResult.released;
    }

    _update((s) => s.copyWith(isLiveAudioStabilizing: true));
    try {
      await player.play();
    } catch (_) {
      if (_isLiveOpenSessionCurrent(sessionToken)) {
        _update(
          (s) => s.copyWith(
            isLiveAudioStabilizing: false,
            isLiveStartupBuffering: false,
          ),
        );
      }
      rethrow;
    }

    if (!_isLiveOpenSessionCurrent(sessionToken)) {
      timing.finish(
        LiveStartupOutcome.sessionAborted,
        abortReason: 'session-replaced-after-play',
      );
      return LivePlaybackFinalizationResult.staleSession;
    }

    AppLogger.info(
      'PlayerNotifier: Live audio warm-up started '
      '(initial=${decodeDecision.name}, max=600ms).',
    );
    late final LiveAudioWarmupResult warmupResult;
    try {
      warmupResult = await timing.measure(
        LiveStartupPhase.stabilization,
        () => waitForLiveAudioWarmup(
          isSessionCurrent: () => _isLiveOpenSessionCurrent(sessionToken),
          hasDecodedAudioInfo: _hasDecodedAudioInfo,
          hasDecodeWarning: () =>
              _lastAudioWarningAt != null &&
              !_lastAudioWarningAt!.isBefore(attemptStartedAt),
        ),
      );
    } finally {
      if (_isLiveOpenSessionCurrent(sessionToken)) {
        _update(
          (s) => s.copyWith(
            isLiveAudioStabilizing: false,
            isLiveStartupBuffering: false,
          ),
        );
      }
    }

    switch (warmupResult) {
      case LiveAudioWarmupResult.staleSession:
        timing.finish(
          LiveStartupOutcome.sessionAborted,
          abortReason: 'session-replaced-during-audio-warmup',
        );
        return LivePlaybackFinalizationResult.staleSession;
      case LiveAudioWarmupResult.decodeFailed:
        AppLogger.warning(
          'PlayerNotifier: Live audio warm-up detected a decode failure; '
          'continuing fallback.',
        );
        return LivePlaybackFinalizationResult.decodeFailed;
      case LiveAudioWarmupResult.confirmed:
        AppLogger.info(
          'PlayerNotifier: Live audio warm-up released after stable decoded parameters.',
        );
      case LiveAudioWarmupResult.provisional:
        AppLogger.info(
          'PlayerNotifier: Live audio warm-up reached 600ms without a decode warning; '
          'releasing provisionally.',
        );
        unawaited(
          _guardLiveAudioAfterOpen(
            player,
            sessionToken: sessionToken,
            openedAt: attemptStartedAt,
          ),
        );
    }

    if (!_isLiveOpenSessionCurrent(sessionToken)) {
      timing.finish(
        LiveStartupOutcome.sessionAborted,
        abortReason: 'session-replaced-after-audio-warmup',
      );
      return LivePlaybackFinalizationResult.staleSession;
    }
    timing.finish(successOutcome);
    return LivePlaybackFinalizationResult.released;
  }

  /// Polls async [stream.error] for ~800 ms after [open].
  ///
  /// When [requirePlaying] is true, the stream must reach the playing state.
  /// When false, the caller only wants to know that the open stayed clean so
  /// live playback can remain paused until a final candidate is chosen.
  Future<bool> _waitForStreamSettled(
    Player player, {
    bool requirePlaying = true,
  }) async {
    const checkInterval = Duration(milliseconds: 100);
    const maxWait = Duration(milliseconds: 800);
    final start = DateTime.now();

    while (DateTime.now().difference(start) < maxWait) {
      final current = state.asData?.value;
      final err = current?.streamError;
      if (err != null && _isOpenErrorMessage(err)) {
        _update((s) => s.copyWith(clearStreamError: true));
        return false;
      }
      if (requirePlaying && player.state.playing) return true;
      await Future<void>.delayed(checkInterval);
    }

    final err = state.asData?.value.streamError;
    if (err != null && _isOpenErrorMessage(err)) {
      _update((s) => s.copyWith(clearStreamError: true));
      return false;
    }
    return !requirePlaying;
  }

  Future<bool> _waitForLiveStartupBuffer(
    Player player,
    int sessionToken,
    int targetSeconds, {
    required Channel? channel,
    required StreamingFallbackAttempt attempt,
    String? deliveryType,
  }) async {
    final target = Duration(seconds: targetSeconds);
    final timeout = liveStartupBufferTimeoutForSeconds(targetSeconds);
    if (target <= Duration.zero || timeout <= Duration.zero) return true;

    _recordStreamingDiagnostic(
      phase: StreamingDiagnosticPhase.prebufferStarted,
      channel: channel,
      attempt: attempt,
      deliveryType: deliveryType,
      duration: Duration.zero,
      diagnosisNote: 'Waiting for ${targetSeconds}s live startup buffer.',
    );
    AppLogger.info(
      'PlayerNotifier: Live startup buffer started after audio validation '
      '(target=${targetSeconds}s).',
    );

    final result = await waitForLiveStartupBuffer(
      target: target,
      timeout: timeout,
      pollInterval: const Duration(milliseconds: 200),
      isSessionCurrent: () async => _isLiveOpenSessionCurrent(sessionToken),
      currentBuffer: () async => player.state.buffer,
    );

    switch (result) {
      case LiveStartupBufferWaitResult.reached:
        _recordStreamingDiagnostic(
          phase: StreamingDiagnosticPhase.prebufferReached,
          channel: channel,
          attempt: attempt,
          deliveryType: deliveryType,
          duration: Duration.zero,
          diagnosisNote:
              'Buffer reached ${player.state.buffer.inMilliseconds / 1000.0}s / ${targetSeconds}s.',
        );
        AppLogger.info('PlayerNotifier: Live startup buffer reached target.');
        // The player was opened paused and cache-pause-initial may try to
        // auto-play once the target is reached. Force an explicit pause so
        // playback is only released when _releasePreparedLivePlayback calls
        // player.play() and updates the UI.
        try {
          await player.pause();
        } catch (e) {
          AppLogger.info(
            'PlayerNotifier: Live startup buffer pause after target skipped: $e',
          );
        }
        return true;
      case LiveStartupBufferWaitResult.cancelled:
        _recordStreamingDiagnostic(
          phase: StreamingDiagnosticPhase.prebufferCancelled,
          channel: channel,
          attempt: attempt,
          deliveryType: deliveryType,
          duration: Duration.zero,
          diagnosisNote:
              'Cancelled because a newer live open session took over.',
        );
        AppLogger.info(
          'PlayerNotifier: Live startup buffer cancelled by new session.',
        );
        _update((s) => s.copyWith(isLiveStartupBuffering: false));
        return false;
      case LiveStartupBufferWaitResult.timedOut:
        _recordStreamingDiagnostic(
          phase: StreamingDiagnosticPhase.prebufferTimedOut,
          channel: channel,
          attempt: attempt,
          deliveryType: deliveryType,
          duration: Duration.zero,
          diagnosisNote: 'Starting live playback anyway after timeout.',
        );
        AppLogger.warning(
          'PlayerNotifier: Live startup buffer timed out; releasing playback.',
        );
        return true;
    }
  }

  Future<bool> _stopLivePlaybackForRetry(
    Player player,
    int sessionToken,
  ) async {
    if (!_isLiveOpenSessionCurrent(sessionToken)) return false;
    try {
      await player.stop();
    } catch (e) {
      AppLogger.info('PlayerNotifier: Live retry stop skipped: $e');
    }
    return _isLiveOpenSessionCurrent(sessionToken);
  }

  Future<VodPreBufferWaitStatus> _waitForVodPreBuffer(
    Player player, {
    required int sessionToken,
  }) async {
    final target =
        ref.read(vodPreBufferTargetSecondsProvider).valueOrNull ??
        VodPreBufferTargetSecondsNotifier.defaultSeconds;
    final deadline = DateTime.now().add(const Duration(seconds: 120));
    while (true) {
      final status = classifyVodPreBufferWait(
        buffered: player.state.buffer,
        targetSeconds: target,
        now: DateTime.now(),
        deadline: deadline,
        isDisposed: _isDisposed,
        isCurrentSession: _isLiveOpenSessionCurrent(sessionToken),
      );
      switch (status) {
        case VodPreBufferWaitStatus.reached:
          AppLogger.info(
            'PlayerNotifier: VOD pre-buffer reached ${player.state.buffer.inSeconds}s.',
          );
          return status;
        case VodPreBufferWaitStatus.cancelled:
          AppLogger.info(
            'PlayerNotifier: VOD pre-buffer cancelled by stop, dispose, or a newer session.',
          );
          return status;
        case VodPreBufferWaitStatus.timedOut:
          AppLogger.info(
            'PlayerNotifier: VOD pre-buffer timed out at ${player.state.buffer.inSeconds}s.',
          );
          return status;
        case VodPreBufferWaitStatus.waiting:
          break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}

final playerNotifierProvider =
    AsyncNotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

/// Incremented by global shortcuts in immersive mode to wake overlay controls.

final immersiveUserActivityTickProvider = StateProvider<int>((ref) => 0);

/// Whether the current selection supports timeline scrubbing (VOD / series episode).

final isSeekableContentProvider = Provider<bool>((ref) {
  return isSeekableChannel(ref.watch(selectedChannelProvider));
});
