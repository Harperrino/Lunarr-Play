import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:m3uxtream_player/core/services/channel_navigation.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/providers/playback_preferences_providers.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/app/composition/player/providers/player_ui_providers.dart';
import 'package:m3uxtream_player/features/player/widgets/audio_track_menu_button.dart';
import 'package:m3uxtream_player/features/player/widgets/player_playback_info_dialog.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';
import 'package:m3uxtream_player/shared/widgets/m3_transport_icon_button.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Player transport - seek scrubber (VOD/series), play/stop, volume, fullscreen.
class PlayerTransportBar extends ConsumerStatefulWidget {
  const PlayerTransportBar({
    super.key,
    required this.onTogglePlay,
    required this.onStop,
    required this.onVolumeChangeEnd,
    required this.onToggleMute,
    this.onVolumeChanged,
    this.compact = false,
    this.translucent = false,
    this.onSeek,
    this.onSeekRelative,
    this.onToggleFullscreen,
    this.onUserActivity,
  });

  final VoidCallback onTogglePlay;
  final VoidCallback onStop;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback onToggleMute;
  final bool compact;
  final bool translucent;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<Duration>? onSeekRelative;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onUserActivity;

  @override
  ConsumerState<PlayerTransportBar> createState() => _PlayerTransportBarState();
}

class _PlayerTransportBarState extends ConsumerState<PlayerTransportBar> {
  double? _dragSeekMs;

  void _zapChannel(int direction) {
    final channels = ref.read(filteredChannelsProvider);
    final selected = ref.read(selectedChannelProvider);
    final channel = navigateChannel(
      channels: channels,
      selected: selected,
      direction: direction,
    );
    if (channel == null) return;

    ref.read(selectedChannelProvider.notifier).state = channel;
    ref.read(playerNotifierProvider.notifier).openStream(channel.streamUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isSeekable = ref.watch(isSeekableContentProvider);
    final hasChannel = ref.watch(
      selectedChannelProvider.select((channel) => channel != null),
    );
    final isLiveChannel = hasChannel && !isSeekable;
    final seekIntervalSeconds =
        ref
            .watch(playbackPreferencesProvider)
            .valueOrNull
            ?.seekIntervalSeconds ??
        const PlaybackPreferences().seekIntervalSeconds;

    final surfaceColor = widget.translucent
        ? Theme.of(context).colorScheme.surfaceContainerHigh
              .withValues(alpha: 0.78)
        : null;

    return AppSurface(
      level: AppSurfaceLevel.high,
      surfaceColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 12 : 14,
        widget.compact ? 10 : 12,
        widget.compact ? 12 : 14,
        widget.compact ? 10 : 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TransportTimelineSection(
            compact: widget.compact,
            isSeekable: isSeekable,
            hasChannel: hasChannel,
            isLiveChannel: isLiveChannel,
            dragSeekMs: _dragSeekMs,
            onDragUpdate: (ms) {
              widget.onUserActivity?.call();
              setState(() => _dragSeekMs = ms);
            },
            onDragEnd: (ms) {
              setState(() => _dragSeekMs = null);
              widget.onSeek?.call(Duration(milliseconds: ms.round()));
            },
          ),
          if (isSeekable || hasChannel)
            SizedBox(height: widget.compact ? 8 : 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;

              final primaryControls = _PrimaryTransportControls(
                compact: widget.compact,
                isLiveChannel: isLiveChannel,
                isSeekable: isSeekable,
                seekIntervalSeconds: seekIntervalSeconds,
                onTogglePlay: () {
                  widget.onUserActivity?.call();
                  widget.onTogglePlay();
                },
                onStop: () {
                  widget.onUserActivity?.call();
                  widget.onStop();
                },
                onZapChannel: (direction) {
                  widget.onUserActivity?.call();
                  _zapChannel(direction);
                },
                onSeekRelative: (delta) {
                  widget.onUserActivity?.call();
                  widget.onSeekRelative?.call(delta);
                },
              );

              final trailingControls = _TrailingTransportControls(
                compact: widget.compact,
                onToggleFullscreen: widget.onToggleFullscreen == null
                    ? null
                    : () {
                        widget.onUserActivity?.call();
                        widget.onToggleFullscreen!();
                      },
                onUserActivity: widget.onUserActivity,
              );
              final volumeControl = _VolumeControl(
                compact: widget.compact,
                onToggleMute: () {
                  widget.onUserActivity?.call();
                  widget.onToggleMute();
                },
                onVolumeChangeEnd: (value) {
                  widget.onUserActivity?.call();
                  widget.onVolumeChangeEnd(value);
                },
                onVolumeChanged: (value) {
                  widget.onVolumeChanged?.call(value);
                },
                onUserActivity: widget.onUserActivity,
              );

              if (narrow) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: primaryControls),
                    SizedBox(height: widget.compact ? 8 : 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(child: volumeControl),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: trailingControls,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return SizedBox(
                height: widget.compact ? 48 : 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: volumeControl,
                    ),
                    Center(child: primaryControls),
                    Align(
                      alignment: Alignment.centerRight,
                      child: trailingControls,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransportTimelineSection extends ConsumerWidget {
  const _TransportTimelineSection({
    required this.compact,
    required this.isSeekable,
    required this.hasChannel,
    required this.isLiveChannel,
    required this.dragSeekMs,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool compact;
  final bool isSeekable;
  final bool hasChannel;
  final bool isLiveChannel;
  final double? dragSeekMs;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSeekable) {
      final scrubberViewModel = ref.watch(playerScrubberViewModelProvider);
      return _VodSeekScrubber(
        viewModel: scrubberViewModel,
        dragSeekMs: dragSeekMs,
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
      );
    }

    if (!hasChannel) {
      return const SizedBox.shrink();
    }

    final liveBufferViewModel = ref.watch(playerLiveBufferViewModelProvider);
    final bufferTargetSeconds = ref.watch(playerBufferTargetSecondsProvider);
    final currentProgramTitle = ref.watch(
      currentProgramTitleForSelectedChannelProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveBufferIndicator(
          buffered: liveBufferViewModel.bufferDuration,
          targetSeconds: bufferTargetSeconds,
          isBuffering: liveBufferViewModel.isBuffering,
          isLiveStartupBuffering: liveBufferViewModel.isLiveStartupBuffering,
        ),
        if (isLiveChannel && currentProgramTitle != null) ...[
          SizedBox(height: compact ? 8 : 10),
          _NowPlayingLine(title: currentProgramTitle),
        ],
      ],
    );
  }
}

class _PrimaryTransportControls extends ConsumerWidget {
  const _PrimaryTransportControls({
    required this.compact,
    required this.isLiveChannel,
    required this.isSeekable,
    required this.seekIntervalSeconds,
    required this.onTogglePlay,
    required this.onStop,
    required this.onZapChannel,
    required this.onSeekRelative,
  });

  final bool compact;
  final bool isLiveChannel;
  final bool isSeekable;
  final int seekIntervalSeconds;
  final VoidCallback onTogglePlay;
  final VoidCallback onStop;
  final ValueChanged<int> onZapChannel;
  final ValueChanged<Duration> onSeekRelative;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playerIsPlayingProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLiveChannel) ...[
          M3TransportIconButton(
            icon: Icons.keyboard_arrow_left_rounded,
            tooltip: context.l10n.playerPreviousChannelTooltip,
            size: compact ? 36 : 40,
            iconSize: 16,
            onPressed: () => onZapChannel(-1),
          ),
          SizedBox(width: compact ? 6 : 8),
        ],
        if (isSeekable) ...[
          M3TransportIconButton(
            icon: Icons.replay_rounded,
            tooltip: context.l10n.playerSeekBackwardTooltip(
              seekIntervalSeconds,
            ),
            size: compact ? 36 : 40,
            iconSize: compact ? 18 : 20,
            onPressed: () =>
                onSeekRelative(Duration(seconds: -seekIntervalSeconds)),
          ),
          SizedBox(width: compact ? 6 : 8),
        ],
        M3TransportIconButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: isPlaying
              ? context.l10n.playerPauseTooltip
              : context.l10n.playerPlayTooltip,
          size: compact ? 48 : 56,
          iconSize: compact ? 20 : 24,
          emphasized: true,
          onPressed: onTogglePlay,
        ),
        if (isSeekable) ...[
          SizedBox(width: compact ? 6 : 8),
          M3TransportIconButton(
            icon: Icons.forward_rounded,
            tooltip: context.l10n.playerSeekForwardTooltip(seekIntervalSeconds),
            size: compact ? 36 : 40,
            iconSize: compact ? 18 : 20,
            onPressed: () =>
                onSeekRelative(Duration(seconds: seekIntervalSeconds)),
          ),
        ],
        SizedBox(width: compact ? 6 : 8),
        M3TransportIconButton(
          icon: Icons.stop_rounded,
          tooltip: context.l10n.playerStopTooltip,
          size: compact ? 36 : 40,
          iconSize: compact ? 17 : 19,
          onPressed: onStop,
        ),
        if (isLiveChannel) ...[
          SizedBox(width: compact ? 6 : 8),
          M3TransportIconButton(
            icon: Icons.keyboard_arrow_right_rounded,
            tooltip: context.l10n.playerNextChannelTooltip,
            size: compact ? 36 : 40,
            iconSize: 16,
            onPressed: () => onZapChannel(1),
          ),
        ],
      ],
    );
  }
}

class _TrailingTransportControls extends ConsumerWidget {
  const _TrailingTransportControls({
    required this.compact,
    required this.onUserActivity,
    this.onToggleFullscreen,
  });

  final bool compact;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onUserActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioTracksViewModel = ref.watch(playerAudioTracksViewModelProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        M3TransportIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: context.l10n.playerPlaybackInfoTooltip,
          size: compact ? 36 : 40,
          iconSize: 16,
          onPressed: () {
            onUserActivity?.call();
            final playerState = ref.read(playerNotifierProvider).valueOrNull;
            if (playerState == null) return;
            showPlayerPlaybackInfoDialog(
              context,
              playerState: playerState,
              channel: ref.read(selectedChannelProvider),
            );
          },
        ),
        SizedBox(width: compact ? 4 : 6),
        AudioTrackMenuButton(
          audioTracks: audioTracksViewModel.audioTracks,
          selectedAudioTrackId: audioTracksViewModel.selectedAudioTrackId,
          compact: compact,
          onUserActivity: onUserActivity,
        ),
        if (onToggleFullscreen != null) ...[
          SizedBox(width: compact ? 4 : 6),
          M3TransportIconButton(
            icon: Icons.fullscreen_rounded,
            tooltip: context.l10n.playerFullscreenTooltip,
            size: compact ? 36 : 40,
            iconSize: 16,
            onPressed: onToggleFullscreen!,
          ),
        ],
      ],
    );
  }
}

class _NowPlayingLine extends StatelessWidget {
  const _NowPlayingLine({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.playerNowPlaying(title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _VodSeekScrubber extends StatelessWidget {
  const _VodSeekScrubber({
    required this.viewModel,
    required this.dragSeekMs,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final PlayerScrubberViewModel viewModel;
  final double? dragSeekMs;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  int get _durationMs {
    final reported = viewModel.duration.inMilliseconds;
    if (reported > 0) return reported;
    final positionMs = viewModel.position.inMilliseconds;
    if (positionMs > 0) {
      return (positionMs * 1.25).clamp(60000, 6 * 3600000).round();
    }
    return 0;
  }

  bool get _scrubEnabled => _durationMs > 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final maxMs = _durationMs;
    final positionMs = dragSeekMs != null
        ? dragSeekMs!.round()
        : viewModel.position.inMilliseconds.clamp(0, maxMs > 0 ? maxMs : 0);
    final forwardMs = viewModel.vodForwardBufferMs;
    final sliderMax = maxMs > 0 ? maxMs.toDouble() : 1.0;
    final bufferedValue = maxMs > 0
        ? vodBufferedEndMs(
            positionMs: positionMs,
            forwardBufferMs: forwardMs,
            durationMs: maxMs,
          ).toDouble()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 28,
          child: M3ExpressiveSlider(
            size: M3ExpressiveSliderSize.xs,
            value: _scrubEnabled
                ? positionMs.toDouble().clamp(0, sliderMax)
                : 0,
            max: sliderMax,
            bufferedValue: forwardMs > 0 ? bufferedValue : null,
            semanticFormatter: (value) => context.l10n.playerPositionSemantics(
              _formatDuration(Duration(milliseconds: value.round())),
            ),
            onChanged: onDragUpdate,
            onChangeEnd: _scrubEnabled ? onDragEnd : null,
            enabled: _scrubEnabled,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 420;
              final leftText = _scrubEnabled
                  ? _formatDuration(Duration(milliseconds: positionMs))
                  : '--:--';
              final middleText =
                  _scrubEnabled && (forwardMs > 0 || viewModel.isBuffering)
                  ? context.l10n.playerBufferedAhead(
                      _formatBufferSeconds(Duration(milliseconds: forwardMs)),
                    )
                  : (viewModel.isBuffering ? context.l10n.playerBuffering : '');
              final rightText = _scrubEnabled
                  ? _formatDuration(Duration(milliseconds: maxMs))
                  : context.l10n.playerLoading;

              final leadStyle = TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              );
              final bufferStyle = TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: viewModel.isBuffering
                    ? (statusColors?.info ?? colorScheme.secondary)
                    : colorScheme.onSurfaceVariant,
              );
              final tailStyle = TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.onSurfaceVariant,
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leftText, style: leadStyle),
                    const SizedBox(height: 4),
                    Text(middleText, style: bufferStyle),
                    const SizedBox(height: 4),
                    Text(rightText, style: tailStyle),
                  ],
                );
              }

              return Row(
                children: [
                  Text(leftText, style: leadStyle),
                  const Spacer(),
                  Text(middleText, style: bufferStyle),
                  const Spacer(),
                  Text(rightText, style: tailStyle),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  static String _formatBufferSeconds(Duration d) {
    final secs = d.inMilliseconds / 1000.0;
    return '${secs.toStringAsFixed(1)}s';
  }
}

/// Read-only buffer fill for live IPTV (`demuxer-cache-time` from mpv).
class _LiveBufferIndicator extends StatelessWidget {
  const _LiveBufferIndicator({
    required this.buffered,
    required this.targetSeconds,
    required this.isBuffering,
    required this.isLiveStartupBuffering,
  });

  final Duration buffered;
  final int targetSeconds;
  final bool isBuffering;
  final bool isLiveStartupBuffering;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColors = Theme.of(context).extension<AppStatusColors>();
    final bufferedSeconds = _clampedSeconds(buffered, targetSeconds);
    final fill = targetSeconds <= 0
        ? 0.0
        : (bufferedSeconds / targetSeconds).clamp(0.0, 1.0);
    final hasBuffer = bufferedSeconds > 0;
    final displayBuffered = Duration(
      milliseconds: (bufferedSeconds * 1000).round(),
    );
    final bufferLabel = _localizedLiveBufferLabel(context, targetSeconds);
    final hasStartupBuffer = targetSeconds > 0 && isLiveStartupBuffering;
    final isLiveRolling = !hasBuffer && !isBuffering && !hasStartupBuffer;
    final isInstantStart = targetSeconds <= 0;
    final leftText = hasStartupBuffer
        ? (hasBuffer
              ? context.l10n.playerStartupBufferProgress(
                  _formatBufferSeconds(displayBuffered),
                  bufferLabel,
                )
              : context.l10n.playerStartupBufferBuilding)
        : hasBuffer
        ? context.l10n.playerBuffered(_formatBufferSeconds(displayBuffered))
        : (isBuffering
              ? context.l10n.playerStabilizingLive
              : (targetSeconds <= 0
                    ? context.l10n.playerLiveInstantStart
                    : context.l10n.playerLiveRollingBuffer));
    final rightText = hasStartupBuffer
        ? context.l10n.playerStartsAtBuffer(bufferLabel)
        : isInstantStart
        ? context.l10n.playerLiveCacheActive
        : isLiveRolling
        ? context.l10n.playerTargetBuffer(bufferLabel)
        : context.l10n.playerMaximumBuffer(
            _formatBufferSeconds(Duration(seconds: targetSeconds)),
          );
    final progressValue = isInstantStart ? 0.0 : (hasBuffer ? fill : null);
    final progressColor = isInstantStart
        ? colorScheme.onSurfaceVariant
        : isBuffering
        ? (statusColors?.info ?? colorScheme.secondary)
        : colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 5,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: progressColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 420;
              final leftStyle = TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              );
              final rightStyle = TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.onSurfaceVariant,
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(leftText, style: leftStyle),
                    const SizedBox(height: 4),
                    Text(rightText, style: rightStyle),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(leftText, style: leftStyle),
                  Text(rightText, style: rightStyle),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static String _formatBufferSeconds(Duration d) {
    final secs = d.inMilliseconds / 1000.0;
    return '${secs.toStringAsFixed(1)}s';
  }

  static double _clampedSeconds(Duration buffered, int targetSeconds) {
    final secs = buffered.inMilliseconds / 1000.0;
    if (targetSeconds <= 0) return 0;
    return secs.clamp(0, targetSeconds.toDouble());
  }
}

/// Material 3 volume control with an always-visible tonal slider.
String _localizedLiveBufferLabel(BuildContext context, int seconds) {
  final normalized = normalizeLiveStartupBufferSeconds(seconds);
  if (normalized == 0) return context.l10n.playbackSettingsBufferOff;
  if (normalized == 120) {
    return context.l10n.playbackSettingsBufferMaximum(normalized);
  }
  return context.l10n.playbackSettingsBufferSeconds(normalized);
}

class _VolumeControl extends ConsumerStatefulWidget {
  const _VolumeControl({
    required this.compact,
    required this.onToggleMute,
    required this.onVolumeChangeEnd,
    this.onVolumeChanged,
    this.onUserActivity,
  });

  final bool compact;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onUserActivity;

  @override
  ConsumerState<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends ConsumerState<_VolumeControl> {
  double? _localVolume;

  IconData _volumeIcon(double volume) {
    if (volume <= 0) return Icons.volume_off_rounded;
    if (volume < 0.35) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final actualVolume = ref.watch(playerVolumeProvider);
    final displayedVolume = (_localVolume ?? actualVolume).clamp(0.0, 1.0);

    return Semantics(
      container: true,
      label: context.l10n.playerVolumeSemantics,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttonSize = widget.compact ? 34.0 : 36.0;
          final preferredSliderWidth = widget.compact ? 104.0 : 124.0;
          final minimumSliderWidth = widget.compact ? 48.0 : 56.0;
          final percentWidth = widget.compact ? 28.0 : 32.0;
          final fixedWidth = buttonSize + 6 + 6 + percentWidth;
          final availableSliderWidth = constraints.maxWidth - fixedWidth;
          final sliderWidth = !constraints.maxWidth.isFinite
              ? preferredSliderWidth
              : availableSliderWidth <= 0
              ? 0.0
              : availableSliderWidth.clamp(
                  minimumSliderWidth,
                  preferredSliderWidth,
                );
          final percentText = '${(displayedVolume * 100).round()}%';
          final percentStyle = TextStyle(
            fontSize: widget.compact ? 10 : 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              M3TransportIconButton(
                icon: _volumeIcon(displayedVolume),
                tooltip: displayedVolume <= 0
                    ? context.l10n.playerUnmuteTooltip
                    : context.l10n.playerMuteTooltip,
                size: buttonSize,
                iconSize: widget.compact ? 15 : 16,
                onPressed: () {
                  widget.onUserActivity?.call();
                  setState(() => _localVolume = null);
                  widget.onToggleMute();
                },
              ),
              SizedBox(
                width: sliderWidth,
                child: M3ExpressiveSlider(
                  size: widget.compact
                      ? M3ExpressiveSliderSize.s
                      : M3ExpressiveSliderSize.m,
                  value: displayedVolume,
                  semanticFormatter: (value) => context.l10n
                      .playerVolumePercentSemantics((value * 100).round()),
                  onChanged: (value) {
                    widget.onUserActivity?.call();
                    setState(() => _localVolume = value);
                    widget.onVolumeChanged?.call(value);
                  },
                  onChangeEnd: (value) {
                    setState(() => _localVolume = null);
                    widget.onVolumeChangeEnd(value);
                  },
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: percentWidth,
                height: buttonSize,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(percentText, style: percentStyle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
