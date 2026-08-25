import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_state.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_assist.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_trickplay_preview.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';
import 'package:m3uxtream_player/shared/widgets/m3_transport_icon_button.dart';
import 'package:m3uxtream_player/shared/widgets/player_chrome.dart';
import 'package:m3uxtream_player/shared/theme/player_chrome_tokens.dart';

/// Jellyfin transport chrome deliberately shares LiveTV's M3 surface,
/// timeline, control geometry and canonical icon buttons.
class JellyfinPlayerControls extends StatelessWidget {
  const JellyfinPlayerControls({
    super.key,
    required this.controller,
    required this.onStop,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onToggleEpisodeOverlay,
    this.episodeOverlayVisible = false,
    this.episodeOverlayButtonFocusNode,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.seekIntervalSeconds = 15,
    this.trickplayManifest,
    this.apiClient,
    this.connection,
    this.itemId,
  });

  final JellyfinPlayerController controller;
  final VoidCallback onStop;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onToggleEpisodeOverlay;
  final bool episodeOverlayVisible;
  final FocusNode? episodeOverlayButtonFocusNode;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final int seekIntervalSeconds;
  final JellyfinTrickplayManifest? trickplayManifest;
  final JellyfinApiClient? apiClient;
  final JellyfinConnection? connection;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<JellyfinPlayerState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final controlsEnabled =
            state.initialized && !state.error && !state.switchingTrack;
        return PlayerChromeSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _JellyfinTimeline(
                state: state,
                enabled: controlsEnabled,
                onSeek: (position) => unawaited(controller.seek(position)),
                trickplayManifest: trickplayManifest,
                apiClient: apiClient,
                connection: connection,
                itemId: itemId,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tokens = PlayerChromeTokens.of(context);
                  final compact =
                      playerChromeWidthClassFor(constraints.maxWidth, tokens) ==
                      PlayerChromeWidthClass.compact;
                  return PlayerChromeControlLayout(
                    compactMetrics: compact,
                    primary: _PrimaryControls(
                      compact: compact,
                      state: state,
                      enabled: controlsEnabled,
                      onTogglePlay: () =>
                          unawaited(controller.togglePlayPause()),
                      onStop: onStop,
                      onPreviousEpisode: onPreviousEpisode,
                      onNextEpisode: onNextEpisode,
                      showEpisodeNavigation: onToggleEpisodeOverlay != null,
                      seekIntervalSeconds: seekIntervalSeconds,
                      onSeekRelative: (delta) =>
                          unawaited(controller.seekRelative(delta)),
                    ),
                    leading: _JellyfinVolumeControl(
                      controller: controller,
                      state: state,
                      enabled: controlsEnabled,
                      compact: compact,
                    ),
                    trailing: _TrackAndFullscreenControls(
                      controller: controller,
                      state: state,
                      enabled: controlsEnabled,
                      compact: compact,
                      isFullscreen: isFullscreen,
                      episodeOverlayVisible: episodeOverlayVisible,
                      episodeOverlayButtonFocusNode:
                          episodeOverlayButtonFocusNode,
                      onToggleEpisodeOverlay: onToggleEpisodeOverlay,
                      onToggleFullscreen: onToggleFullscreen,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JellyfinTimeline extends StatefulWidget {
  const _JellyfinTimeline({
    required this.state,
    required this.enabled,
    required this.onSeek,
    this.trickplayManifest,
    this.apiClient,
    this.connection,
    this.itemId,
  });

  final JellyfinPlayerState state;
  final bool enabled;
  final ValueChanged<Duration> onSeek;
  final JellyfinTrickplayManifest? trickplayManifest;
  final JellyfinApiClient? apiClient;
  final JellyfinConnection? connection;
  final String? itemId;

  @override
  State<_JellyfinTimeline> createState() => _JellyfinTimelineState();
}

class _JellyfinTimelineState extends State<_JellyfinTimeline> {
  double? _dragSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final durationSeconds = widget.state.duration.inSeconds;
    final maximum = durationSeconds > 0 ? durationSeconds.toDouble() : 1.0;
    final position =
        (_dragSeconds ?? widget.state.position.inSeconds.toDouble()).clamp(
          0.0,
          maximum,
        );
    final positionLabel = durationSeconds > 0
        ? jellyfinFormatDuration(Duration(seconds: position.round()))
        : '--:--';
    final durationLabel = durationSeconds > 0
        ? jellyfinFormatDuration(widget.state.duration)
        : l10n.jellyfinDurationUnknown;
    final textStyle = TextStyle(
      fontSize: 11,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_dragSeconds != null &&
            widget.trickplayManifest != null &&
            widget.apiClient != null &&
            widget.connection != null &&
            widget.itemId != null)
          JellyfinTrickplayPreview(
            apiClient: widget.apiClient!,
            connection: widget.connection!,
            itemId: widget.itemId!,
            manifest: widget.trickplayManifest!,
            position: Duration(seconds: position.round()),
          ),
        SizedBox(
          height: 28,
          child: M3ExpressiveSlider(
            key: const ValueKey('jellyfin-seek-slider'),
            size: M3ExpressiveSliderSize.xs,
            value: position,
            max: maximum,
            enabled: widget.enabled && durationSeconds > 0,
            semanticFormatter: (value) => l10n.playerPositionSemantics(
              jellyfinFormatDuration(Duration(seconds: value.round())),
            ),
            onChanged: (value) => setState(() => _dragSeconds = value),
            onChangeEnd: widget.enabled && durationSeconds > 0
                ? (value) {
                    setState(() => _dragSeconds = null);
                    widget.onSeek(Duration(seconds: value.round()));
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(positionLabel, style: textStyle),
              Text(durationLabel, style: textStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    required this.compact,
    required this.state,
    required this.enabled,
    required this.onTogglePlay,
    required this.onStop,
    required this.onPreviousEpisode,
    required this.onNextEpisode,
    required this.showEpisodeNavigation,
    required this.seekIntervalSeconds,
    required this.onSeekRelative,
  });

  final bool compact;
  final JellyfinPlayerState state;
  final bool enabled;
  final VoidCallback onTogglePlay;
  final VoidCallback onStop;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final bool showEpisodeNavigation;
  final int seekIntervalSeconds;
  final ValueChanged<Duration> onSeekRelative;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = PlayerChromeTokens.of(context);
    final controlSize = compact
        ? tokens.compactControlExtent
        : tokens.controlExtent;
    final iconSize = compact ? tokens.compactIconExtent : tokens.iconExtent;
    return PlayerPrimaryControlGroup(
      compact: compact,
      children: [
        if (showEpisodeNavigation)
          M3TransportIconButton(
            icon: Icons.skip_previous_rounded,
            tooltip: l10n.jellyfinPreviousEpisodeTooltip,
            size: controlSize,
            iconSize: iconSize,
            onPressed: onPreviousEpisode,
          ),
        M3TransportIconButton(
          icon: Icons.replay_rounded,
          tooltip: l10n.playerSeekBackwardTooltip(seekIntervalSeconds),
          size: controlSize,
          iconSize: iconSize,
          onPressed: enabled
              ? () => onSeekRelative(Duration(seconds: -seekIntervalSeconds))
              : null,
        ),
        M3TransportIconButton(
          icon: state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: state.playing
              ? l10n.playerPauseTooltip
              : l10n.playerPlayTooltip,
          size: compact ? tokens.primaryCompactExtent : tokens.primaryExtent,
          iconSize: compact
              ? tokens.primaryCompactIconExtent
              : tokens.primaryIconExtent,
          emphasized: true,
          onPressed: enabled ? onTogglePlay : null,
        ),
        M3TransportIconButton(
          icon: Icons.forward_rounded,
          tooltip: l10n.playerSeekForwardTooltip(seekIntervalSeconds),
          size: controlSize,
          iconSize: iconSize,
          onPressed: enabled
              ? () => onSeekRelative(Duration(seconds: seekIntervalSeconds))
              : null,
        ),
        if (showEpisodeNavigation)
          M3TransportIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: l10n.jellyfinNextEpisodeTooltip,
            size: controlSize,
            iconSize: iconSize,
            onPressed: onNextEpisode,
          ),
        M3TransportIconButton(
          icon: Icons.stop_rounded,
          tooltip: l10n.playerStopTooltip,
          size: controlSize,
          iconSize: iconSize,
          onPressed: onStop,
        ),
      ],
    );
  }
}

class _TrackAndFullscreenControls extends StatelessWidget {
  const _TrackAndFullscreenControls({
    required this.controller,
    required this.state,
    required this.enabled,
    required this.compact,
    required this.isFullscreen,
    required this.episodeOverlayVisible,
    this.episodeOverlayButtonFocusNode,
    this.onToggleEpisodeOverlay,
    this.onToggleFullscreen,
  });

  final JellyfinPlayerController controller;
  final JellyfinPlayerState state;
  final bool enabled;
  final bool compact;
  final bool isFullscreen;
  final bool episodeOverlayVisible;
  final FocusNode? episodeOverlayButtonFocusNode;
  final VoidCallback? onToggleEpisodeOverlay;
  final VoidCallback? onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = PlayerChromeTokens.of(context);
    final size = compact ? tokens.compactControlExtent : tokens.controlExtent;
    final iconSize = compact ? 15.0 : 16.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onToggleEpisodeOverlay != null) ...[
          Focus(
            key: const ValueKey('jellyfin-episode-overlay-button'),
            focusNode: episodeOverlayButtonFocusNode,
            child: M3TransportIconButton(
              key: const ValueKey('jellyfin-episode-picker-button'),
              icon: episodeOverlayVisible
                  ? Icons.close_rounded
                  : Icons.video_library_rounded,
              tooltip: episodeOverlayVisible
                  ? l10n.jellyfinHideEpisodesTooltip
                  : l10n.jellyfinShowEpisodesTooltip,
              size: size,
              iconSize: iconSize,
              onPressed: onToggleEpisodeOverlay,
            ),
          ),
          SizedBox(width: compact ? 4 : 6),
        ],
        PopupMenuButton<int>(
          enabled: enabled && state.audioTracks.isNotEmpty,
          tooltip: l10n.jellyfinAudioTrackTooltip,
          initialValue: state.selectedAudioStreamIndex >= 0
              ? state.selectedAudioStreamIndex
              : null,
          onSelected: (index) => unawaited(controller.selectAudioTrack(index)),
          itemBuilder: (context) => [
            for (final track in state.audioTracks)
              PopupMenuItem<int>(
                value: track.index,
                child: Text(jellyfinStreamDisplayLabel(track)),
              ),
          ],
          child: M3TransportIconButton(
            icon: Icons.audiotrack_rounded,
            tooltip: l10n.jellyfinAudioTrackTooltip,
            size: size,
            iconSize: iconSize,
            onPressed: null,
          ),
        ),
        SizedBox(width: compact ? 4 : 6),
        PopupMenuButton<int>(
          enabled: enabled && state.subtitleTracks.isNotEmpty,
          tooltip: l10n.jellyfinSubtitleTrackTooltip,
          initialValue: state.selectedSubtitleStreamIndex,
          onSelected: (index) => unawaited(
            controller.selectSubtitleTrack(index < 0 ? null : index),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<int>(
              value: -1,
              child: Text(l10n.jellyfinSubtitleOff),
            ),
            for (final track in state.subtitleTracks)
              PopupMenuItem<int>(
                value: track.index,
                child: Text(jellyfinStreamDisplayLabel(track)),
              ),
          ],
          child: M3TransportIconButton(
            icon: Icons.subtitles_rounded,
            tooltip: l10n.jellyfinSubtitleTrackTooltip,
            size: size,
            iconSize: iconSize,
            onPressed: null,
          ),
        ),
        if (onToggleFullscreen != null) ...[
          SizedBox(width: compact ? 4 : 6),
          M3TransportIconButton(
            icon: isFullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tooltip: l10n.playerFullscreenTooltip,
            size: size,
            iconSize: iconSize,
            onPressed: onToggleFullscreen,
          ),
        ],
      ],
    );
  }
}

class _JellyfinVolumeControl extends StatefulWidget {
  const _JellyfinVolumeControl({
    required this.controller,
    required this.state,
    required this.enabled,
    required this.compact,
  });

  final JellyfinPlayerController controller;
  final JellyfinPlayerState state;
  final bool enabled;
  final bool compact;

  @override
  State<_JellyfinVolumeControl> createState() => _JellyfinVolumeControlState();
}

class _JellyfinVolumeControlState extends State<_JellyfinVolumeControl> {
  double? _localVolume;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = (_localVolume ?? widget.state.volume).clamp(0.0, 1.0);
    final tokens = PlayerChromeTokens.of(context);
    final buttonSize = widget.compact
        ? tokens.compactControlExtent
        : tokens.controlExtent;
    final sliderWidth = widget.compact ? 104.0 : 124.0;
    final percentWidth = widget.compact ? 28.0 : 32.0;
    final icon = value <= 0
        ? Icons.volume_off_rounded
        : value < 0.35
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;
    return PlayerVolumeCluster(
      semanticLabel: l10n.playerVolumeSemantics,
      muteButton: M3TransportIconButton(
        key: const ValueKey('jellyfin-mute-button'),
        icon: icon,
        tooltip: value <= 0 ? l10n.playerUnmuteTooltip : l10n.playerMuteTooltip,
        size: buttonSize,
        iconSize: widget.compact ? 15 : 16,
        onPressed: widget.enabled
            ? () {
                setState(() => _localVolume = null);
                unawaited(widget.controller.toggleMute());
              }
            : null,
      ),
      slider: SizedBox(
        width: sliderWidth,
        child: M3ExpressiveSlider(
          key: const ValueKey('jellyfin-volume-slider'),
          size: widget.compact
              ? M3ExpressiveSliderSize.s
              : M3ExpressiveSliderSize.m,
          value: value,
          enabled: widget.enabled,
          semanticFormatter: (next) =>
              l10n.playerVolumePercentSemantics((next * 100).round()),
          onChanged: (next) {
            setState(() => _localVolume = next);
            unawaited(widget.controller.setVolume(next));
          },
          onChangeEnd: (next) {
            setState(() => _localVolume = null);
            unawaited(widget.controller.setVolume(next));
          },
        ),
      ),
      valueLabel: SizedBox(
        width: percentWidth,
        height: buttonSize,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            context.l10n.jellyfinVolumePercent((value * 100).round()),
            key: const ValueKey('jellyfin-volume-percent'),
            style: TextStyle(
              fontSize: widget.compact ? 10 : 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
