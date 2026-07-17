import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_command_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_ui_providers.dart';
import 'package:m3uxtream_player/features/player/services/player_ui_command_runner.dart';
import 'package:m3uxtream_player/features/player/vod/vod_main_video_surface_gate.dart';
import 'package:m3uxtream_player/features/player/widgets/player_transport_bar.dart';
import 'package:m3uxtream_player/features/player/widgets/player_stage_components.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Semantic color tones used by the playback status badge.
enum PlayerStatusTone { error, idle, warning, info, playing, paused }

/// Resolves playback status colors from the active Material theme roles.
Color playerStatusColorFor(BuildContext context, PlayerStatusTone tone) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final status = theme.extension<AppStatusColors>();

  return switch (tone) {
    PlayerStatusTone.error => colors.error,
    PlayerStatusTone.idle => colors.onSurfaceVariant,
    PlayerStatusTone.warning => status?.warning ?? colors.tertiary,
    PlayerStatusTone.info => status?.info ?? colors.secondary,
    PlayerStatusTone.playing => status?.success ?? colors.primary,
    PlayerStatusTone.paused => colors.tertiary,
  };
}

/// Live playback panel - video surface, status badge, and transport controls.
class PlayerPanel extends ConsumerStatefulWidget {
  const PlayerPanel({
    super.key,
    this.immersive = false,
    this.onToggleFullscreen,
  });

  /// When true, video fills available space with overlay controls (fullscreen live mode).
  final bool immersive;
  final VoidCallback? onToggleFullscreen;

  @override
  ConsumerState<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends ConsumerState<PlayerPanel> {
  static const _controlsHideDelay = Duration(seconds: 3);
  static const _controlsAnimDuration = Duration(milliseconds: 280);
  static const _compactPanelMaxWidth = 440.0;

  bool _immersiveControlsVisible = true;
  Timer? _immersiveHideTimer;

  @override
  void initState() {
    super.initState();
    if (widget.immersive) {
      _scheduleImmersiveHide();
    }
  }

  @override
  void didUpdateWidget(PlayerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.immersive && !oldWidget.immersive) {
      setState(() => _immersiveControlsVisible = true);
      _scheduleImmersiveHide();
    } else if (!widget.immersive && oldWidget.immersive) {
      _cancelImmersiveHideTimer();
      _immersiveControlsVisible = true;
    }
  }

  @override
  void dispose() {
    _cancelImmersiveHideTimer();
    super.dispose();
  }

  void _cancelImmersiveHideTimer() {
    _immersiveHideTimer?.cancel();
    _immersiveHideTimer = null;
  }

  void _scheduleImmersiveHide() {
    if (!widget.immersive) return;
    _cancelImmersiveHideTimer();
    _immersiveHideTimer = Timer(_controlsHideDelay, () {
      if (!mounted || !widget.immersive) return;
      setState(() => _immersiveControlsVisible = false);
    });
  }

  void _onImmersiveUserActivity() {
    if (!widget.immersive) return;
    if (!_immersiveControlsVisible) {
      setState(() => _immersiveControlsVisible = true);
    }
    _scheduleImmersiveHide();
  }

  void _toggleImmersiveControls() {
    if (!widget.immersive) return;
    setState(() => _immersiveControlsVisible = !_immersiveControlsVisible);
    if (_immersiveControlsVisible) {
      _scheduleImmersiveHide();
    } else {
      _cancelImmersiveHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(immersiveUserActivityTickProvider, (previous, next) {
      if (widget.immersive && previous != next) {
        _onImmersiveUserActivity();
      }
    });

    final isLoading = ref.watch(playerPanelLoadingProvider);
    final errorMessage = ref.watch(playerPanelErrorMessageProvider);
    final hasPanelStatus = isLoading || errorMessage != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            !widget.immersive &&
            (constraints.maxHeight < 600 ||
                constraints.maxWidth < _compactPanelMaxWidth);
        final stage = isLoading
            ? PlayerStageFrame(
                immersive: widget.immersive,
                child: const PlayerStageLoading(),
              )
            : errorMessage != null
            ? PlayerStageFrame(
                immersive: widget.immersive,
                child: PlayerStageError(
                  message: errorMessage,
                  immersive: widget.immersive,
                ),
              )
            : _PlayerVideoAreaSection(immersive: widget.immersive);
        final videoArea = widget.immersive
            ? stage
            : Center(
                child: AspectRatio(aspectRatio: 16 / 9, child: stage),
              );

        final panelBody = Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.immersive && !hasPanelStatus)
                  _PlayerHeaderSection(compact: compact),
                Expanded(child: videoArea),
                if (!widget.immersive && !hasPanelStatus) ...[
                  SizedBox(height: compact ? 12 : 16),
                  PlayerTransportBar(
                    compact: compact,
                    onTogglePlay: _handleTogglePlay,
                    onStop: _handleStop,
                    onVolumeChanged: _handleVolumeChanged,
                    onVolumeChangeEnd: _handleVolumeChangeEnd,
                    onToggleMute: _handleToggleMute,
                    onSeek: (position) => ref
                        .read(playerNotifierProvider.notifier)
                        .seek(position),
                    onToggleFullscreen: widget.onToggleFullscreen,
                  ),
                ],
              ],
            ),
            if (widget.immersive) ...[
              Positioned.fill(
                child: MouseRegion(
                  onHover: (_) => _onImmersiveUserActivity(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleImmersiveControls,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  key: const ValueKey('immersive-controls-layer'),
                  opacity: _immersiveControlsVisible ? 1.0 : 0.0,
                  duration: _controlsAnimDuration,
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !_immersiveControlsVisible,
                    child: _ImmersiveControlsOverlay(
                      onTogglePlay: _handleTogglePlay,
                      onStop: _handleStop,
                      onVolumeChanged: _handleVolumeChanged,
                      onVolumeChangeEnd: _handleVolumeChangeEnd,
                      onToggleMute: _handleToggleMute,
                      onSeek: (position) => ref
                          .read(playerNotifierProvider.notifier)
                          .seek(position),
                      onUserActivity: _onImmersiveUserActivity,
                      onToggleFullscreen: widget.onToggleFullscreen,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );

        if (widget.immersive) {
          return ColoredBox(color: Colors.black, child: panelBody);
        }

        return AppSurface(
          level: AppSurfaceLevel.standard,
          elevation: AppElevation.level2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(compact ? 18.0 : 24.0),
          child: panelBody,
        );
      },
    );
  }

  void _handleTogglePlay() {
    unawaited(
      ref
          .read(playerUiCommandRunnerProvider)
          .togglePlay(origin: PlayerUiCommandOrigin.panel),
    );
    _onImmersiveUserActivity();
  }

  void _handleStop() {
    unawaited(
      ref
          .read(playerUiCommandRunnerProvider)
          .stop(origin: PlayerUiCommandOrigin.panel),
    );
    _onImmersiveUserActivity();
  }

  void _handleVolumeChangeEnd(double value) {
    unawaited(
      ref
          .read(playerUiCommandRunnerProvider)
          .setVolume(value, origin: PlayerUiCommandOrigin.panel),
    );
    _onImmersiveUserActivity();
  }

  void _handleVolumeChanged(double value) {
    unawaited(
      ref.read(playerNotifierProvider.notifier).setVolumeNormalized(value),
    );
  }

  Future<void> _handleToggleMute() async {
    await ref.read(playerNotifierProvider.notifier).toggleMute();
    _onImmersiveUserActivity();
  }
}

class _ImmersiveControlsOverlay extends ConsumerWidget {
  const _ImmersiveControlsOverlay({
    required this.onTogglePlay,
    required this.onStop,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onToggleMute,
    required this.onSeek,
    required this.onUserActivity,
    this.onToggleFullscreen,
  });

  final VoidCallback onTogglePlay;
  final VoidCallback onStop;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final VoidCallback onToggleMute;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onUserActivity;
  final VoidCallback? onToggleFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerViewModel = ref.watch(playerHeaderViewModelProvider);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      headerViewModel.channelName ?? 'No channel selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _StatusBadge(
                    label: !headerViewModel.hasSelectedChannel
                        ? 'IDLE'
                        : headerViewModel.isLiveAudioStabilizing
                        ? 'STABILIZING'
                        : headerViewModel.isLiveStartupBuffering
                        ? 'WARMING UP'
                        : headerViewModel.isBuffering
                        ? 'BUFFERING'
                        : headerViewModel.isPlaying
                        ? 'LIVE'
                        : 'PAUSED',
                    tone: !headerViewModel.hasSelectedChannel
                        ? PlayerStatusTone.idle
                        : headerViewModel.isLiveAudioStabilizing
                        ? PlayerStatusTone.warning
                        : headerViewModel.isLiveStartupBuffering
                        ? PlayerStatusTone.info
                        : headerViewModel.isBuffering
                        ? PlayerStatusTone.info
                        : headerViewModel.isPlaying
                        ? PlayerStatusTone.playing
                        : PlayerStatusTone.paused,
                  ),
                ],
              ),
              if (headerViewModel.currentProgramTitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  headerViewModel.currentProgramTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Press F or Esc to exit fullscreen',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 14),
              PlayerTransportBar(
                translucent: true,
                onTogglePlay: onTogglePlay,
                onStop: onStop,
                onVolumeChanged: onVolumeChanged,
                onVolumeChangeEnd: onVolumeChangeEnd,
                onToggleMute: onToggleMute,
                onSeek: onSeek,
                onToggleFullscreen: onToggleFullscreen,
                onUserActivity: onUserActivity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerHeaderSection extends ConsumerWidget {
  const _PlayerHeaderSection({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerViewModel = ref.watch(playerHeaderViewModelProvider);
    return _PlayerHeader(viewModel: headerViewModel, compact: compact);
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.viewModel, this.compact = false});

  final PlayerHeaderViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasError = viewModel.streamError != null;
    final colors = Theme.of(context).colorScheme;

    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: colors.onPrimaryContainer,
              size: compact ? 20 : 22,
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE PLAYBACK',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: compact ? 13 : 14,
                    letterSpacing: 0.5,
                  ),
                ),
                if (viewModel.channelName != null)
                  Text(
                    viewModel.channelName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10.5 : 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if (viewModel.currentProgramTitle != null)
                  Text(
                    viewModel.currentProgramTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9.5 : 10,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.74),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          _StatusBadge(
            compact: compact,
            label: hasError
                ? 'ERROR'
                : !viewModel.hasSelectedChannel
                ? 'READY'
                : viewModel.isLiveAudioStabilizing
                ? 'STABILIZING'
                : viewModel.isBuffering
                ? 'CONNECTING'
                : viewModel.isPlaying
                ? 'ON AIR'
                : 'PAUSED',
            tone: hasError
                ? PlayerStatusTone.error
                : !viewModel.hasSelectedChannel
                ? PlayerStatusTone.idle
                : viewModel.isLiveAudioStabilizing
                ? PlayerStatusTone.warning
                : viewModel.isBuffering
                ? PlayerStatusTone.info
                : viewModel.isPlaying
                ? PlayerStatusTone.playing
                : PlayerStatusTone.paused,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.tone,
    this.compact = false,
  });

  final String label;
  final PlayerStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = playerStatusColorFor(context, tone);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              color: onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerVideoAreaSection extends ConsumerWidget {
  const _PlayerVideoAreaSection({required this.immersive});

  final bool immersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(playerVideoViewModelProvider);
    // Avoid creating a VideoController / native texture while no stream is active.
    final controller = viewModel.player == null || viewModel.playbackUri == null
        ? null
        : ref
              .read(playerNotifierProvider.notifier)
              .videoControllerFor(viewModel.player!);

    return _PlayerVideoArea(
      controller: controller,
      viewModel: viewModel,
      immersive: immersive,
    );
  }
}

class _PlayerVideoArea extends StatelessWidget {
  const _PlayerVideoArea({
    required this.controller,
    required this.viewModel,
    required this.immersive,
  });

  final VideoController? controller;
  final PlayerVideoViewModel viewModel;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    return PlayerStageFrame(
      immersive: immersive,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (!viewModel.hasSelectedChannel || viewModel.playbackUri == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (immersive)
            PlayerMessage(
              icon: Icons.play_arrow_rounded,
              title: 'Select a channel',
              subtitle:
                  'Exit fullscreen (F / Esc) and pick a channel from the list.',
              iconColor: Colors.white.withValues(alpha: 0.3),
              immersive: true,
            )
          else
            const WindowedPlayerEmptyState(),
          const _PlayerPreparationOverlayLayer(),
        ],
      );
    }

    if (controller == null) {
      return PlayerMessage(
        icon: Icons.error_outline_rounded,
        title: 'Playback failed',
        subtitle: viewModel.streamError ?? 'Could not initialize video output.',
        iconColor: immersive ? Colors.redAccent : colors.error,
        error: true,
        immersive: immersive,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _VodMainVideoSurfaceMarker(
          enabled: viewModel.markVodMainSurface,
          playbackUri: viewModel.playbackUri,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            child: Video(
              key: ValueKey(
                viewModel.videoSurfaceKey ?? 'player-video-surface',
              ),
              controller: controller!,
              fit: BoxFit.contain,
              controls: NoVideoControls,
            ),
          ),
        ),
        const _PlayerPreparationOverlayLayer(),
        if (viewModel.streamError != null)
          _StreamErrorBanner(
            message: viewModel.streamError!,
            immersive: immersive,
          ),
      ],
    );
  }
}

class _PlayerPreparationOverlayLayer extends ConsumerWidget {
  const _PlayerPreparationOverlayLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(playerPreparationOverlayProvider);
    if (!viewModel.showOverlay) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: ColoredBox(
        color: colors.scrim.withValues(alpha: 0.55),
        child: Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: AppOverlaySurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      viewModel.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      viewModel.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (viewModel.showProgress) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: viewModel.progressValue,
                          minHeight: 6,
                          backgroundColor: colors.surfaceContainerLow,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamErrorBanner extends StatelessWidget {
  const _StreamErrorBanner({required this.message, required this.immersive});

  final String message;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = immersive
        ? Colors.black.withValues(alpha: 0.75)
        : colors.errorContainer;
    final iconColor = immersive ? Colors.redAccent : colors.error;
    final textColor = immersive ? Colors.white70 : colors.onErrorContainer;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: iconColor, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Signals that the live-tab [Video] surface is mounted (VOD start gate).
class _VodMainVideoSurfaceMarker extends ConsumerStatefulWidget {
  const _VodMainVideoSurfaceMarker({
    required this.enabled,
    required this.playbackUri,
    required this.child,
  });

  final bool enabled;
  final String? playbackUri;
  final Widget child;

  @override
  ConsumerState<_VodMainVideoSurfaceMarker> createState() =>
      _VodMainVideoSurfaceMarkerState();
}

class _VodMainVideoSurfaceMarkerState
    extends ConsumerState<_VodMainVideoSurfaceMarker> {
  @override
  void initState() {
    super.initState();
    _markReadyNextFrame();
  }

  @override
  void didUpdateWidget(_VodMainVideoSurfaceMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled &&
        (oldWidget.playbackUri != widget.playbackUri || !oldWidget.enabled)) {
      ref.read(vodMainVideoSurfaceReadyProvider.notifier).state = false;
      _markReadyNextFrame();
    }
  }

  void _markReadyNextFrame() {
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      ref.read(vodMainVideoSurfaceReadyProvider.notifier).state = true;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
