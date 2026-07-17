import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';

typedef PlayerHeaderViewModel = ({
  String? channelName,
  String? currentProgramTitle,
  bool hasSelectedChannel,
  bool isBuffering,
  bool isPlaying,
  bool isLiveStartupBuffering,
  bool isLiveAudioStabilizing,
  String? streamError,
});

typedef PlayerVideoViewModel = ({
  Player? player,
  String? playbackUri,
  String? streamError,
  String? videoSurfaceKey,
  bool hasSelectedChannel,
  bool isBuffering,
  bool isLiveStartupBuffering,
  bool markVodMainSurface,
});

typedef PlayerScrubberViewModel = ({
  Duration position,
  Duration duration,
  int vodForwardBufferMs,
  bool isBuffering,
});

typedef PlayerLiveBufferViewModel = ({
  Duration bufferDuration,
  bool isBuffering,
  bool isLiveStartupBuffering,
});

typedef PlayerAudioTracksViewModel = ({
  List<AudioTrack> audioTracks,
  String? selectedAudioTrackId,
});

typedef PlayerPreparationOverlayViewModel = ({
  bool showOverlay,
  String title,
  String subtitle,
  bool showProgress,
  double? progressValue,
});

final currentProgramTitleForSelectedChannelProvider =
    Provider.autoDispose<String?>((ref) {
      final channel = ref.watch(selectedChannelProvider);
      if (channel == null) return null;

      final matchStatus = ref.watch(epgMatchStatusProvider(channel.id));
      if (matchStatus != EpgMatchStatus.matched) return null;

      return ref
          .watch(currentProgramForChannelProvider(channel.id))
          .valueOrNull
          ?.title;
    });

final playerPanelLoadingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    playerNotifierProvider.select((playerAsync) => playerAsync.isLoading),
  );
});

final playerPanelErrorMessageProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(
    playerNotifierProvider.select(
      (playerAsync) =>
          playerAsync.whenOrNull(error: (error, _) => 'Player error: $error'),
    ),
  );
});

final playerVolumeProvider = Provider.autoDispose<double>((ref) {
  return ref.watch(
    playerNotifierProvider.select(
      (playerAsync) => playerVolumeValue(playerAsync.valueOrNull),
    ),
  );
});

final playerIsPlayingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    playerNotifierProvider.select(
      (playerAsync) => playerIsPlayingValue(playerAsync.valueOrNull),
    ),
  );
});

final playerBufferTargetSecondsProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(playerBufferSecondsProvider).valueOrNull ??
      PlayerBufferSecondsNotifier.defaultSeconds;
});

final playerHeaderViewModelProvider =
    Provider.autoDispose<PlayerHeaderViewModel>((ref) {
      final playerState = ref.watch(
        playerNotifierProvider.select(
          (playerAsync) => playerAsync.valueOrNull == null
              ? null
              : (
                  isBuffering: playerAsync.valueOrNull!.isBuffering,
                  isPlaying: playerAsync.valueOrNull!.isPlaying,
                  isLiveStartupBuffering:
                      playerAsync.valueOrNull!.isLiveStartupBuffering,
                  isLiveAudioStabilizing:
                      playerAsync.valueOrNull!.isLiveAudioStabilizing,
                  streamError: playerAsync.valueOrNull!.streamError,
                ),
        ),
      );
      final selectedChannel = ref.watch(selectedChannelProvider);
      final currentProgramTitle = ref.watch(
        currentProgramTitleForSelectedChannelProvider,
      );
      return buildPlayerHeaderViewModel(
        channelName: selectedChannel?.name,
        hasSelectedChannel: selectedChannel != null,
        currentProgramTitle: currentProgramTitle,
        isBuffering: playerState?.isBuffering ?? false,
        isPlaying: playerState?.isPlaying ?? false,
        isLiveStartupBuffering: playerState?.isLiveStartupBuffering ?? false,
        isLiveAudioStabilizing: playerState?.isLiveAudioStabilizing ?? false,
        streamError: playerState?.streamError,
      );
    });

final playerVideoViewModelProvider = Provider.autoDispose<PlayerVideoViewModel>(
  (ref) {
    final playerState = ref.watch(
      playerNotifierProvider.select(
        (playerAsync) => playerAsync.valueOrNull == null
            ? null
            : (
                player: playerAsync.valueOrNull!.player,
                playbackUri: playerAsync.valueOrNull!.playbackUri,
                streamError: playerAsync.valueOrNull!.streamError,
                isBuffering: playerAsync.valueOrNull!.isBuffering,
                isLiveStartupBuffering:
                    playerAsync.valueOrNull!.isLiveStartupBuffering,
              ),
      ),
    );
    final selectedChannel = ref.watch(selectedChannelProvider);
    return buildPlayerVideoViewModel(
      player: playerState?.player,
      playbackUri: playerState?.playbackUri,
      streamError: playerState?.streamError,
      selectedChannel: selectedChannel,
      isBuffering: playerState?.isBuffering ?? false,
      isLiveStartupBuffering: playerState?.isLiveStartupBuffering ?? false,
    );
  },
);

final playerScrubberViewModelProvider =
    Provider.autoDispose<PlayerScrubberViewModel>((ref) {
      final playerState = ref.watch(
        playerNotifierProvider.select(
          (playerAsync) => playerAsync.valueOrNull == null
              ? null
              : (
                  position: playerAsync.valueOrNull!.position,
                  duration: playerAsync.valueOrNull!.duration,
                  vodForwardBufferMs:
                      playerAsync.valueOrNull!.vodForwardBufferMs,
                  isBuffering: playerAsync.valueOrNull!.isBuffering,
                ),
        ),
      );
      return buildPlayerScrubberViewModel(
        position: playerState?.position ?? Duration.zero,
        duration: playerState?.duration ?? Duration.zero,
        vodForwardBufferMs: playerState?.vodForwardBufferMs ?? 0,
        isBuffering: playerState?.isBuffering ?? false,
      );
    });

final playerLiveBufferViewModelProvider =
    Provider.autoDispose<PlayerLiveBufferViewModel>((ref) {
      final playerState = ref.watch(
        playerNotifierProvider.select(
          (playerAsync) => playerAsync.valueOrNull == null
              ? null
              : (
                  bufferDuration: playerAsync.valueOrNull!.bufferDuration,
                  isBuffering: playerAsync.valueOrNull!.isBuffering,
                  isLiveStartupBuffering:
                      playerAsync.valueOrNull!.isLiveStartupBuffering,
                ),
        ),
      );
      return buildPlayerLiveBufferViewModel(
        bufferDuration: playerState?.bufferDuration ?? Duration.zero,
        isBuffering: playerState?.isBuffering ?? false,
        isLiveStartupBuffering: playerState?.isLiveStartupBuffering ?? false,
      );
    });

final playerAudioTracksViewModelProvider =
    Provider.autoDispose<PlayerAudioTracksViewModel>((ref) {
      final playerState = ref.watch(
        playerNotifierProvider.select(
          (playerAsync) => playerAsync.valueOrNull == null
              ? null
              : (
                  audioTracks: playerAsync.valueOrNull!.audioTracks,
                  selectedAudioTrackId:
                      playerAsync.valueOrNull!.selectedAudioTrackId,
                ),
        ),
      );
      return buildPlayerAudioTracksViewModel(
        audioTracks: playerState?.audioTracks ?? const [],
        selectedAudioTrackId: playerState?.selectedAudioTrackId,
      );
    });

final playerPreparationOverlayProvider =
    Provider.autoDispose<PlayerPreparationOverlayViewModel>((ref) {
      final playerState = ref.watch(
        playerNotifierProvider.select(
          (playerAsync) => playerAsync.valueOrNull == null
              ? null
              : (
                  playbackUri: playerAsync.valueOrNull!.playbackUri,
                  isPlaying: playerAsync.valueOrNull!.isPlaying,
                  isBuffering: playerAsync.valueOrNull!.isBuffering,
                  isLiveStartupBuffering:
                      playerAsync.valueOrNull!.isLiveStartupBuffering,
                  isLiveAudioStabilizing:
                      playerAsync.valueOrNull!.isLiveAudioStabilizing,
                  isLiveAudioAwaiting:
                      playerAsync.valueOrNull!.isLiveAudioAwaiting,
                  audioTracks: playerAsync.valueOrNull!.audioTracks,
                  bufferDuration: playerAsync.valueOrNull!.bufferDuration,
                ),
        ),
      );
      final bufferTargetSeconds = ref.watch(playerBufferTargetSecondsProvider);
      final isSeekable = ref.watch(isSeekableContentProvider);

      return buildPlayerPreparationOverlayViewModel(
        playbackUri: playerState?.playbackUri,
        isPlaying: playerState?.isPlaying ?? false,
        isBuffering: playerState?.isBuffering ?? false,
        isLiveStartupBuffering: playerState?.isLiveStartupBuffering ?? false,
        isLiveAudioStabilizing: playerState?.isLiveAudioStabilizing ?? false,
        isLiveAudioAwaiting: playerState?.isLiveAudioAwaiting ?? false,
        audioTracks: playerState?.audioTracks ?? const [],
        bufferDuration: playerState?.bufferDuration ?? Duration.zero,
        bufferTargetSeconds: bufferTargetSeconds,
        isSeekable: isSeekable,
      );
    });

PlayerHeaderViewModel buildPlayerHeaderViewModel({
  required String? channelName,
  required bool hasSelectedChannel,
  required String? currentProgramTitle,
  required bool isBuffering,
  required bool isPlaying,
  required bool isLiveStartupBuffering,
  required bool isLiveAudioStabilizing,
  required String? streamError,
}) {
  return (
    channelName: channelName,
    currentProgramTitle: currentProgramTitle,
    hasSelectedChannel: hasSelectedChannel,
    isBuffering: isBuffering,
    isPlaying: isPlaying,
    isLiveStartupBuffering: isLiveStartupBuffering,
    isLiveAudioStabilizing: isLiveAudioStabilizing,
    streamError: streamError,
  );
}

PlayerVideoViewModel buildPlayerVideoViewModel({
  required Player? player,
  required String? playbackUri,
  required String? streamError,
  required Channel? selectedChannel,
  required bool isBuffering,
  required bool isLiveStartupBuffering,
}) {
  return (
    player: player,
    playbackUri: playbackUri,
    streamError: streamError,
    videoSurfaceKey: playbackUri,
    hasSelectedChannel: selectedChannel != null,
    isBuffering: isBuffering,
    isLiveStartupBuffering: isLiveStartupBuffering,
    markVodMainSurface: isSeekableChannel(selectedChannel),
  );
}

PlayerScrubberViewModel buildPlayerScrubberViewModel({
  required Duration position,
  required Duration duration,
  required int vodForwardBufferMs,
  required bool isBuffering,
}) {
  return (
    position: position,
    duration: duration,
    vodForwardBufferMs: vodForwardBufferMs,
    isBuffering: isBuffering,
  );
}

PlayerLiveBufferViewModel buildPlayerLiveBufferViewModel({
  required Duration bufferDuration,
  required bool isBuffering,
  required bool isLiveStartupBuffering,
}) {
  return (
    bufferDuration: bufferDuration,
    isBuffering: isBuffering,
    isLiveStartupBuffering: isLiveStartupBuffering,
  );
}

PlayerAudioTracksViewModel buildPlayerAudioTracksViewModel({
  required List<AudioTrack> audioTracks,
  required String? selectedAudioTrackId,
}) {
  return (audioTracks: audioTracks, selectedAudioTrackId: selectedAudioTrackId);
}

PlayerPreparationOverlayViewModel buildPlayerPreparationOverlayViewModel({
  required String? playbackUri,
  required bool isPlaying,
  required bool isBuffering,
  required bool isLiveStartupBuffering,
  required bool isLiveAudioStabilizing,
  required bool isLiveAudioAwaiting,
  required List<AudioTrack> audioTracks,
  required Duration bufferDuration,
  required int bufferTargetSeconds,
  required bool isSeekable,
}) {
  // VOD/Series uses its own prep flow; never show the live preparation overlay.
  if (isSeekable) {
    return (
      showOverlay: false,
      title: '',
      subtitle: '',
      showProgress: false,
      progressValue: null,
    );
  }

  final isPreparing =
      isLiveAudioStabilizing ||
      (!isPlaying &&
          (isBuffering || isLiveStartupBuffering || isLiveAudioAwaiting));

  if (!isPreparing) {
    return (
      showOverlay: false,
      title: '',
      subtitle: '',
      showProgress: false,
      progressValue: null,
    );
  }

  if (isLiveAudioAwaiting) {
    return (
      showOverlay: true,
      title: 'Audio wird erkannt',
      subtitle: 'Audiospur wird erkannt…',
      showProgress: true,
      progressValue: null,
    );
  }

  if (isLiveAudioStabilizing) {
    return (
      showOverlay: true,
      title: 'Audio wird synchronisiert',
      subtitle: 'Audiospur stabilisieren…',
      showProgress: true,
      progressValue: null,
    );
  }

  if (isLiveStartupBuffering) {
    final subtitle = bufferTargetSeconds <= 0
        ? 'Sofortstart aktiv'
        : 'Start bei ${labelForLiveStartupBufferSeconds(bufferTargetSeconds)} Buffer';
    final bufferedSeconds = bufferDuration.inMilliseconds / 1000.0;
    final target = bufferTargetSeconds <= 0
        ? 1.0
        : bufferTargetSeconds.toDouble();
    final progressValue = (bufferedSeconds / target).clamp(0.0, 1.0);
    return (
      showOverlay: true,
      title: 'Live-Puffer wird aufgebaut',
      subtitle: subtitle,
      showProgress: true,
      progressValue: progressValue,
    );
  }

  final hasAudioTracks = audioTracks.isNotEmpty;
  return (
    showOverlay: true,
    title: 'Stream wird vorbereitet',
    subtitle: hasAudioTracks
        ? 'Audio wird erkannt…'
        : 'Verbindung wird hergestellt…',
    showProgress: true,
    progressValue: null,
  );
}

double playerVolumeValue(PlayerState? playerState) {
  return playerState?.volume ?? 0.8;
}

bool playerIsPlayingValue(PlayerState? playerState) {
  return playerState?.isPlaying ?? false;
}
