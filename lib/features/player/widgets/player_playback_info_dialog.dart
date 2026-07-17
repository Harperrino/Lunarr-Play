import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/live_audio_track_service.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Stream / playback details (bitrate, resolution, codecs).
String audioTrackExposureStatusLabel(int rawCount, int selectableCount) {
  if (rawCount == 0) {
    return 'No raw audio tracks detected';
  }
  if (selectableCount == 0) {
    return 'Audio tracks detected, none currently selectable';
  }
  return '$rawCount raw / $selectableCount selectable';
}

String audioTrackDisplayLabel({
  required String currentTrackId,
  required int rawCount,
  required int selectableCount,
}) {
  if (currentTrackId == AudioTrack.auto().id && selectableCount == 0) {
    return rawCount == 0
        ? 'Audio track not exposed by stream/demuxer'
        : 'Audio tracks detected, none currently selectable';
  }

  if (currentTrackId == AudioTrack.auto().id) return 'Auto';
  if (currentTrackId == AudioTrack.no().id) return 'Keine';
  return currentTrackId;
}

void showPlayerPlaybackInfoDialog(
  BuildContext context, {
  required PlayerState playerState,
  required Channel? channel,
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _PlayerPlaybackInfoDialog(playerState: playerState, channel: channel),
  );
}

class _PlayerPlaybackInfoDialog extends StatelessWidget {
  const _PlayerPlaybackInfoDialog({
    required this.playerState,
    required this.channel,
  });

  final PlayerState playerState;
  final Channel? channel;

  @override
  Widget build(BuildContext context) {
    final info = playerState.mediaInfo;
    final audioTrackLabel = _audioTrackLabel(playerState);
    final audioCompatibilityHint = decodedAudioCompatibilityHint(info);
    final isVod =
        channel != null &&
        (channel!.channelType == 'vod' || channel!.channelType == 'series');
    final maxDialogHeight = (MediaQuery.sizeOf(context).height - 96)
        .clamp(0.0, double.infinity)
        .toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: SingleChildScrollView(
            child: AppSurface(
              level: AppSurfaceLevel.high,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Wiedergabe-Informationen',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 15),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Schliessen',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Titel', value: channel?.name ?? '-'),
                  if (channel?.groupName != null &&
                      channel!.groupName!.isNotEmpty)
                    _InfoRow(label: 'Gruppe', value: channel!.groupName!),
                  _InfoRow(
                    label: 'Typ',
                    value: _channelTypeLabel(channel?.channelType),
                  ),
                  Divider(
                    height: 24,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _InfoRow(
                    label: 'Aufloesung',
                    value: info.resolutionLabel ?? '-',
                  ),
                  _InfoRow(
                    label: 'Video-Format',
                    value: info.videoPixelFormat ?? '-',
                  ),
                  _InfoRow(label: 'Audio-Spur', value: audioTrackLabel),
                  _InfoRow(
                    label: 'Audio-Track-Status',
                    value: _audioTrackExposureLabel(playerState),
                  ),
                  _InfoRow(
                    label: 'Audio dekodiert',
                    value: info.hasAudioInfo ? 'Ja' : 'Nein',
                  ),
                  _InfoRow(
                    label: 'Audio-Format',
                    value: info.audioFormat ?? '-',
                  ),
                  _InfoRow(
                    label: 'Audio-Kanaele',
                    value:
                        info.audioChannelsLabel ??
                        (info.audioChannelCount != null
                            ? '${info.audioChannelCount}'
                            : '-'),
                  ),
                  if (audioCompatibilityHint != null)
                    _InfoRow(
                      label: 'Audio-Hinweis',
                      value: audioCompatibilityHint,
                    ),
                  _InfoRow(
                    label: 'Sample-Rate',
                    value: info.audioSampleRate != null
                        ? '${info.audioSampleRate} Hz'
                        : '-',
                  ),
                  _InfoRow(
                    label: 'Audio-Bitrate',
                    value: info.audioBitrateKbps != null
                        ? '${info.audioBitrateKbps!.toStringAsFixed(0)} kbps'
                        : '-',
                  ),
                  _InfoRow(
                    label: 'Container',
                    value: info.containerLabel ?? '-',
                  ),
                  Divider(
                    height: 24,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _InfoRow(
                    label: 'Position',
                    value: _formatClock(playerState.position),
                  ),
                  _InfoRow(
                    label: 'Dauer',
                    value: playerState.hasFiniteDuration
                        ? _formatClock(playerState.duration)
                        : '-',
                  ),
                  if (isVod) ...[
                    _InfoRow(
                      label: 'Puffer (Demuxer)',
                      value: _formatBuffer(playerState.bufferDuration),
                    ),
                    _InfoRow(
                      label: 'Voraus gepuffert bis',
                      value: playerState.hasFiniteDuration
                          ? _formatClock(
                              Duration(
                                milliseconds: vodBufferedEndMs(
                                  positionMs:
                                      playerState.position.inMilliseconds,
                                  forwardBufferMs:
                                      playerState.vodForwardBufferMs,
                                  durationMs:
                                      playerState.duration.inMilliseconds,
                                ),
                              ),
                            )
                          : '-',
                    ),
                  ],
                  _InfoRow(
                    label: 'Status',
                    value: playerState.isBuffering
                        ? 'Puffert...'
                        : (playerState.isPlaying ? 'Wiedergabe' : 'Pause'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _channelTypeLabel(String? type) {
    return switch (type) {
      'vod' => 'Film (VOD)',
      'series' => 'Serie / Episode',
      'live' => 'Live TV',
      _ => type ?? '-',
    };
  }

  static String _formatClock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  static String _formatBuffer(Duration d) {
    final secs = d.inMilliseconds / 1000.0;
    return '${secs.toStringAsFixed(1)} s';
  }

  static String _audioTrackLabel(PlayerState playerState) {
    final track = playerState.player.state.track.audio;
    if (track.id == AudioTrack.auto().id || track.id == AudioTrack.no().id) {
      return audioTrackDisplayLabel(
        currentTrackId: track.id,
        rawCount: playerState.player.state.tracks.audio.length,
        selectableCount: playerState.audioTracks.length,
      );
    }
    return LiveAudioTrackService.labelFor(track);
  }

  static String _audioTrackExposureLabel(PlayerState playerState) {
    return audioTrackExposureStatusLabel(
      playerState.player.state.tracks.audio.length,
      playerState.audioTracks.length,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
