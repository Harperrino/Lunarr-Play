import 'package:drift/drift.dart' show Value;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/player/vod/vod_main_video_surface_gate.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/xtream/models/playback_prep_target.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:window_manager/window_manager.dart';

export 'package:m3uxtream_player/features/xtream/models/playback_prep_target.dart';

/// Active prep target (movie or episode). Null = catalogue visible.
final playbackPrepTargetProvider = StateProvider<PlaybackPrepTarget?>((ref) {
  ref.listen<int?>(selectedPlaylistIdProvider, (previous, next) {
    if (previous != next) {
      ref
          .read(playbackPrepControllerProvider.notifier)
          .resetForPlaylistChange();
    }
  });
  return null;
});

enum PlaybackPrepPhase { idle, preparing, ready, error }

class PlaybackPrepState {
  const PlaybackPrepState({
    this.phase = PlaybackPrepPhase.idle,
    this.errorMessage,
  });

  final PlaybackPrepPhase phase;
  final String? errorMessage;

  bool get isBusy => phase == PlaybackPrepPhase.preparing;
}

final playbackPrepControllerProvider =
    NotifierProvider<PlaybackPrepController, PlaybackPrepState>(
      PlaybackPrepController.new,
    );

final playbackPrepMediaInfoProvider = Provider<PlaybackMediaInfo>((ref) {
  return ref.watch(
    playerNotifierProvider.select(
      (state) => state.valueOrNull?.mediaInfo ?? PlaybackMediaInfo.empty,
    ),
  );
});

final playbackPrepBufferDurationProvider = Provider<Duration>((ref) {
  return ref.watch(
    playerNotifierProvider.select(
      (state) => state.valueOrNull?.bufferDuration ?? Duration.zero,
    ),
  );
});

class PlaybackPrepController extends Notifier<PlaybackPrepState> {
  int _playlistSelectionGeneration = 0;

  @override
  PlaybackPrepState build() => const PlaybackPrepState();

  /// Drops all catalogue-owned preparation state after a playlist switch.
  ///
  /// The generation also prevents a pre-switch asynchronous prepare operation
  /// from publishing a ready/error state after its target has been cleared.
  void resetForPlaylistChange() {
    _playlistSelectionGeneration++;
    ref.read(playbackPrepTargetProvider.notifier).state = null;
    ref.read(seriesActivePlaybackProvider.notifier).state = null;
    state = const PlaybackPrepState();
  }

  void selectTarget(PlaybackPrepTarget target) {
    ref.read(playbackPrepTargetProvider.notifier).state = target;
    state = const PlaybackPrepState();
  }

  void clearSelection() {
    ref.read(playbackPrepTargetProvider.notifier).state = null;
    state = const PlaybackPrepState();
  }

  Future<void> prepareSelected() async {
    final target = ref.read(playbackPrepTargetProvider);
    if (target == null || state.isBusy) return;
    final selectionGeneration = _playlistSelectionGeneration;

    state = const PlaybackPrepState(phase: PlaybackPrepPhase.preparing);
    ref.read(selectedChannelProvider.notifier).state = target.playbackChannel;

    try {
      final preBuffer =
          ref.read(vodPreBufferEnabledProvider).valueOrNull ?? true;
      await ref
          .read(playerNotifierProvider.notifier)
          .openStream(
            target.streamUrl,
            startPosition: target.startPosition > Duration.zero
                ? target.startPosition
                : null,
            startPaused: true,
            preBuffer: preBuffer,
          );
      if (selectionGeneration != _playlistSelectionGeneration) return;
      state = const PlaybackPrepState(phase: PlaybackPrepPhase.ready);
    } catch (e, stackTrace) {
      if (selectionGeneration != _playlistSelectionGeneration) return;
      AppLogger.error('PlaybackPrepController: prepare failed', e, stackTrace);
      state = PlaybackPrepState(
        phase: PlaybackPrepPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startPlayback() async {
    final target = ref.read(playbackPrepTargetProvider);
    final selectionGeneration = _playlistSelectionGeneration;

    resetVodMainVideoSurfaceReady(ref);

    if (ref.read(isDesktopPlatformProvider)) {
      try {
        if (await windowManager.isFullScreen()) {
          ref.read(isFullscreenProvider.notifier).state = false;
          await windowManager.setFullScreen(false);
          await SchedulerBinding.instance.endOfFrame;
        }
      } catch (e, stackTrace) {
        AppLogger.error(
          'PlaybackPrepController: Failed to exit fullscreen before VOD start',
          e,
          stackTrace,
        );
      }
    }

    if (selectionGeneration != _playlistSelectionGeneration) return;

    final previousSidebarIndex = ref.read(activeSidebarIndexProvider);
    ref.read(activeSidebarIndexProvider.notifier).state = 0;

    final surfaceReady = await waitForVodMainVideoSurface(
      () => ref.read(vodMainVideoSurfaceReadyProvider),
    );
    if (!surfaceReady) {
      const message =
          'Video-Ausgabe wurde nicht rechtzeitig bereit. Bitte Wiedergabe erneut starten.';
      AppLogger.error(
        'PlaybackPrepController: VOD main video surface timed out',
        message,
      );
      state = const PlaybackPrepState(
        phase: PlaybackPrepPhase.error,
        errorMessage: message,
      );
      if (previousSidebarIndex != 0) {
        ref.read(activeSidebarIndexProvider.notifier).state =
            previousSidebarIndex;
      }
      return;
    }

    if (selectionGeneration != _playlistSelectionGeneration) return;

    clearSelection();
    await SchedulerBinding.instance.endOfFrame;

    await ref.read(playerNotifierProvider.notifier).startVodPreparedPlayback();

    if (selectionGeneration != _playlistSelectionGeneration) return;

    final activeSeries = ref.read(seriesActivePlaybackProvider);
    if (activeSeries != null) {
      final positionMs =
          ref
              .read(playerNotifierProvider)
              .valueOrNull
              ?.position
              .inMilliseconds ??
          target?.startPosition.inMilliseconds ??
          0;
      await saveSeriesResumeData(
        repository: ref.read(appStateRepositoryProvider),
        playback: activeSeries,
        positionMs: positionMs,
      );
      ref.invalidate(seriesResumeProvider(activeSeries.seriesChannelDbId));
    }
  }

  Future<void> cancel() async {
    final target = ref.read(playbackPrepTargetProvider);
    if (target != null) {
      final selected = ref.read(selectedChannelProvider);
      if (selected?.id == target.playbackChannel.id) {
        await ref.read(playerNotifierProvider.notifier).stopStream();
      }
    }
    clearSelection();
  }
}

/// Pre-buffer progress 0.0–1.0 while preparing.
final playbackPrepBufferProgressProvider = Provider<double>((ref) {
  final prep = ref.watch(playbackPrepControllerProvider);
  if (prep.phase != PlaybackPrepPhase.preparing) {
    return prep.phase == PlaybackPrepPhase.ready ? 1.0 : 0.0;
  }
  final bufferDuration = ref.watch(playbackPrepBufferDurationProvider);
  final target =
      ref.watch(vodPreBufferTargetSecondsProvider).valueOrNull ??
      VodPreBufferTargetSecondsNotifier.defaultSeconds;
  if (target <= 0) return 0.0;
  return (bufferDuration.inSeconds / target).clamp(0.0, 1.0);
});

/// Opens the pre-buffer prep screen for a series episode (same flow as VOD movies).
void selectSeriesEpisodePrep(
  WidgetRef ref, {
  required Channel seriesChannel,
  required ParsedSeriesEpisode episode,
  int startPositionMs = 0,
}) {
  final playlistId = ref.read(selectedPlaylistIdProvider);
  final seriesStreamId = seriesChannel.streamId;
  if (playlistId == null || seriesStreamId == null || seriesStreamId.isEmpty) {
    return;
  }

  ref.read(seriesActivePlaybackProvider.notifier).state = SeriesActivePlayback(
    playlistId: playlistId,
    seriesStreamId: seriesStreamId,
    seriesChannelDbId: seriesChannel.id,
    episode: episode,
  );

  final playbackChannel = seriesChannel.copyWith(
    name: seriesChannel.name,
    streamUrl: episode.streamUrl,
    streamId: Value(episode.episodeId),
    channelType: 'series',
  );

  ref
      .read(playbackPrepControllerProvider.notifier)
      .selectTarget(
        PlaybackPrepTarget(
          playbackChannel: playbackChannel,
          streamUrl: episode.streamUrl,
          startPosition: Duration(milliseconds: startPositionMs),
          posterUrl: seriesChannel.logo,
          subtitle: '${formatEpisodeSubtitle(episode)} — ${episode.title}',
          isSeries: true,
        ),
      );
}
