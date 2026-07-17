import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_providers.dart';

class _FakePlayer extends Fake implements Player {}

void main() {
  final player = _FakePlayer();
  const selectedChannel = Channel(
    id: 7,
    playlistId: 1,
    name: 'Demo Channel',
    streamUrl: 'https://example.com/live.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
  );

  test('position ticks change scrubber state but not header view model', () {
    final baseState = PlayerState(
      player: player,
      isPlaying: true,
      volume: 0.5,
      isBuffering: false,
      isLiveStartupBuffering: false,
      position: const Duration(seconds: 10),
      duration: const Duration(minutes: 30),
      vodForwardBufferMs: 3000,
    );
    final updatedState = baseState.copyWith(
      position: const Duration(seconds: 18),
      vodForwardBufferMs: 5200,
    );

    expect(
      _headerViewModelFor(
        baseState,
        channel: selectedChannel,
        title: 'Current Show',
      ),
      _headerViewModelFor(
        updatedState,
        channel: selectedChannel,
        title: 'Current Show',
      ),
    );
    expect(
      _scrubberViewModelFor(baseState),
      isNot(_scrubberViewModelFor(updatedState)),
    );
  });

  test('playbackUri changes update the video surface view model', () {
    final baseState = PlayerState(
      player: player,
      isPlaying: true,
      volume: 0.5,
      playbackUri: 'https://example.com/a.m3u8',
    );
    final updatedState = baseState.copyWith(
      playbackUri: 'https://example.com/b.m3u8',
    );

    final baseViewModel = _videoViewModelFor(
      baseState,
      channel: selectedChannel,
    );
    final updatedViewModel = _videoViewModelFor(
      updatedState,
      channel: selectedChannel,
    );

    expect(baseViewModel, isNot(updatedViewModel));
    expect(updatedViewModel.playbackUri, 'https://example.com/b.m3u8');
    expect(updatedViewModel.videoSurfaceKey, 'https://example.com/b.m3u8');
  });

  test('videoSurfaceKey is null when playbackUri is null', () {
    final viewModel = _videoViewModelFor(
      PlayerState(
        player: player,
        isPlaying: false,
        volume: 0.5,
        playbackUri: null,
      ),
      channel: selectedChannel,
    );

    expect(viewModel.playbackUri, isNull);
    expect(viewModel.videoSurfaceKey, isNull);
  });

  test('preparation overlay is hidden for VOD/series content', () {
    final viewModel = buildPlayerPreparationOverlayViewModel(
      playbackUri: 'https://example.com/vod.mp4',
      isPlaying: false,
      isBuffering: true,
      isLiveStartupBuffering: false,
      isLiveAudioStabilizing: false,
      isLiveAudioAwaiting: false,
      audioTracks: const [],
      bufferDuration: Duration.zero,
      bufferTargetSeconds: 15,
      isSeekable: true,
    );

    expect(viewModel.showOverlay, isFalse);
  });

  test(
    'preparation overlay is hidden when live playback is already playing',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: 'https://example.com/live.m3u8',
        isPlaying: true,
        isBuffering: false,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isFalse);
    },
  );

  test(
    'preparation overlay is hidden on fast path once live prep flags are cleared',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: 'https://example.com/live.m3u8',
        isPlaying: false,
        isBuffering: false,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [
          AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 2),
        ],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isFalse);
    },
  );

  test(
    'preparation overlay shows connecting state while live stream prepares',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: 'https://example.com/live.m3u8',
        isPlaying: false,
        isBuffering: true,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isTrue);
      expect(viewModel.title, 'Stream wird vorbereitet');
      expect(viewModel.subtitle, 'Verbindung wird hergestellt…');
    },
  );

  test('preparation overlay shows audio stabilizing state', () {
    final viewModel = buildPlayerPreparationOverlayViewModel(
      playbackUri: 'https://example.com/live.m3u8',
      isPlaying: false,
      isBuffering: false,
      isLiveStartupBuffering: false,
      isLiveAudioStabilizing: true,
      isLiveAudioAwaiting: false,
      audioTracks: const [
        AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 2),
      ],
      bufferDuration: Duration.zero,
      bufferTargetSeconds: 15,
      isSeekable: false,
    );

    expect(viewModel.showOverlay, isTrue);
    expect(viewModel.title, 'Audio wird synchronisiert');
    expect(viewModel.subtitle, 'Audiospur stabilisieren…');
  });

  test('preparation overlay stays visible while audio warm-up is playing', () {
    final viewModel = buildPlayerPreparationOverlayViewModel(
      playbackUri: 'https://example.com/live.m3u8',
      isPlaying: true,
      isBuffering: false,
      isLiveStartupBuffering: false,
      isLiveAudioStabilizing: true,
      isLiveAudioAwaiting: false,
      audioTracks: const [AudioTrack('1', 'Main', 'deu', codec: 'ac3')],
      bufferDuration: Duration.zero,
      bufferTargetSeconds: 15,
      isSeekable: false,
    );

    expect(viewModel.showOverlay, isTrue);
    expect(viewModel.title, 'Audio wird synchronisiert');
  });

  test(
    'preparation overlay shows audio awaiting state while late audio is detected',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: 'https://example.com/live.m3u8',
        isPlaying: false,
        isBuffering: true,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: true,
        audioTracks: const [],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isTrue);
      expect(viewModel.title, 'Audio wird erkannt');
      expect(viewModel.subtitle, 'Audiospur wird erkannt…');
    },
  );

  test('preparation overlay shows startup buffer progress', () {
    final viewModel = buildPlayerPreparationOverlayViewModel(
      playbackUri: 'https://example.com/live.m3u8',
      isPlaying: false,
      isBuffering: false,
      isLiveStartupBuffering: true,
      isLiveAudioStabilizing: false,
      isLiveAudioAwaiting: false,
      audioTracks: const [],
      bufferDuration: const Duration(seconds: 7),
      bufferTargetSeconds: 15,
      isSeekable: false,
    );

    expect(viewModel.showOverlay, isTrue);
    expect(viewModel.title, 'Live-Puffer wird aufgebaut');
    expect(viewModel.progressValue, closeTo(7 / 15, 0.001));
  });

  test(
    'preparation overlay shows audio detecting state when tracks exist but not yet stable',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: 'https://example.com/live.m3u8',
        isPlaying: false,
        isBuffering: true,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [
          AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 6),
        ],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isTrue);
      expect(viewModel.title, 'Stream wird vorbereitet');
      expect(viewModel.subtitle, 'Audio wird erkannt…');
    },
  );

  test(
    'preparation overlay shows connecting state while live opens before playbackUri is set',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: null,
        isPlaying: false,
        isBuffering: true,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isTrue);
      expect(viewModel.title, 'Stream wird vorbereitet');
      expect(viewModel.subtitle, 'Verbindung wird hergestellt…');
    },
  );

  test(
    'preparation overlay is hidden when live is idle with all prep flags false',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: null,
        isPlaying: false,
        isBuffering: false,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: false,
      );

      expect(viewModel.showOverlay, isFalse);
    },
  );

  test(
    'preparation overlay remains hidden for VOD/series even while buffering',
    () {
      final viewModel = buildPlayerPreparationOverlayViewModel(
        playbackUri: null,
        isPlaying: false,
        isBuffering: true,
        isLiveStartupBuffering: false,
        isLiveAudioStabilizing: false,
        isLiveAudioAwaiting: false,
        audioTracks: const [],
        bufferDuration: Duration.zero,
        bufferTargetSeconds: 15,
        isSeekable: true,
      );

      expect(viewModel.showOverlay, isFalse);
    },
  );

  test(
    'volume changes affect only the volume slice, not audio tracks slice',
    () {
      final baseState = PlayerState(
        player: player,
        isPlaying: true,
        volume: 0.25,
        audioTracks: const [],
        selectedAudioTrackId: null,
      );
      final updatedState = baseState.copyWith(volume: 0.8);

      expect(playerVolumeValue(baseState), 0.25);
      expect(playerVolumeValue(updatedState), 0.8);
      expect(
        buildPlayerAudioTracksViewModel(
          audioTracks: baseState.audioTracks,
          selectedAudioTrackId: baseState.selectedAudioTrackId,
        ),
        buildPlayerAudioTracksViewModel(
          audioTracks: updatedState.audioTracks,
          selectedAudioTrackId: updatedState.selectedAudioTrackId,
        ),
      );
    },
  );
}

PlayerHeaderViewModel _headerViewModelFor(
  PlayerState state, {
  required Channel? channel,
  required String? title,
}) {
  return buildPlayerHeaderViewModel(
    channelName: channel?.name,
    hasSelectedChannel: channel != null,
    currentProgramTitle: title,
    isBuffering: state.isBuffering,
    isPlaying: state.isPlaying,
    isLiveStartupBuffering: state.isLiveStartupBuffering,
    isLiveAudioStabilizing: state.isLiveAudioStabilizing,
    streamError: state.streamError,
  );
}

PlayerVideoViewModel _videoViewModelFor(
  PlayerState state, {
  required Channel? channel,
}) {
  return buildPlayerVideoViewModel(
    player: state.player,
    playbackUri: state.playbackUri,
    streamError: state.streamError,
    selectedChannel: channel,
    isBuffering: state.isBuffering,
    isLiveStartupBuffering: state.isLiveStartupBuffering,
  );
}

PlayerScrubberViewModel _scrubberViewModelFor(PlayerState state) {
  return buildPlayerScrubberViewModel(
    position: state.position,
    duration: state.duration,
    vodForwardBufferMs: state.vodForwardBufferMs,
    isBuffering: state.isBuffering,
  );
}
