import 'package:media_kit/media_kit.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_audio_track_service.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';

/// Builds redacted streaming diagnostics and formats player audio snapshots.
///
/// Persistence and provider ownership stay outside this service. Keeping the
/// mapping here makes redaction a single, testable boundary.
class PlayerDiagnosticsReporter {
  const PlayerDiagnosticsReporter();

  StreamingDiagnosticEvent createStreamingEvent({
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
    DateTime? timestamp,
  }) {
    return StreamingDiagnosticEvent(
      timestamp: timestamp ?? DateTime.now(),
      phase: phase,
      channelName: channel?.name,
      channelId: channel?.id.toString(),
      sourceUrlRedacted: redactStreamUrl(attempt.sourceUrl),
      playbackUrlRedacted: redactStreamUrl(attempt.playbackUrl),
      fallbackLabel: attempt.label,
      headerProfile: attempt.headerProfile,
      deliveryType: deliveryType ?? attempt.deliveryType,
      httpStatus: httpStatus,
      contentType: contentType,
      mpvError: mpvError == null ? null : redactStreamText(mpvError),
      failureKind: failureKind,
      duration: duration,
      diagnosisNote: diagnosisNote == null
          ? null
          : redactStreamText(diagnosisNote),
    );
  }

  void logAudioSnapshot({
    required Player player,
    required String stage,
    required List<AudioTrack> rawTracks,
    required List<AudioTrack> selectableTracks,
    required bool forceStereoEnabled,
    required LiveStreamDelivery delivery,
    required String? appliedDemuxerLavfFormat,
    required String? selectedAudioTrackId,
    required PlaybackMediaInfo? mediaInfo,
    required String? streamError,
  }) {
    final rawDescription = LiveAudioTrackService.describeTracks(rawTracks);
    final selectableDescription = LiveAudioTrackService.describeTracks(
      selectableTracks,
    );
    final selectedTrackDescription = LiveAudioTrackService.diagnosticLabelFor(
      player.state.track.audio,
    );
    final rawTrackDetails = rawTracks.isEmpty
        ? '[]'
        : rawTracks
              .asMap()
              .entries
              .map((entry) {
                return LiveAudioTrackService.diagnosticDetailsFor(
                  entry.value,
                  fallbackIndex: entry.key + 1,
                );
              })
              .join('\n  ');
    final demuxerFormat = PlayerBufferService.demuxerLavfFormatForDelivery(
      delivery,
    );
    final demuxerState =
        appliedDemuxerLavfFormat ??
        (demuxerFormat.isEmpty ? 'cleared' : demuxerFormat);
    final redactedStreamError = streamError == null
        ? 'n/a'
        : redactStreamText(streamError);

    AppLogger.info(
      'PlayerNotifier: Audio diagnostics [$stage] '
      'delivery=${delivery.diagnosticLabel} '
      'demuxer-lavf-format=$demuxerState '
      'forceStereo=${forceStereoEnabled ? 'on' : 'off'}\n'
      '  rawTracks(${rawTracks.length}): $rawDescription\n'
      '  selectableTracks(${selectableTracks.length}): $selectableDescription\n'
      '  selectedAudioTrackId=${selectedAudioTrackId ?? 'auto'}\n'
      '  player.state.track.audio=$selectedTrackDescription\n'
      '  audioParams=${audioParamsLabel(mediaInfo)}\n'
      '  audioBitrate=${audioBitrateLabel(mediaInfo)}\n'
      '  streamError=$redactedStreamError',
    );

    if (rawTracks.isNotEmpty && selectableTracks.isEmpty) {
      AppLogger.info(
        'PlayerNotifier: Raw audio track details [$stage]\n  $rawTrackDetails',
      );
      for (final track in rawTracks) {
        AppLogger.info(
          'PlayerNotifier: Raw audio track filter [$stage] '
          '${LiveAudioTrackService.diagnosticDetailsFor(track)} -> '
          '${LiveAudioTrackService.trackFilterReason(track)}',
        );
      }
    }
  }

  String audioParamsLabel(PlaybackMediaInfo? info) {
    if (info == null) return 'n/a';
    final parts = <String>[];
    if (info.audioFormat case final format? when format.isNotEmpty) {
      parts.add('format=$format');
    }
    if (info.audioSampleRate case final sampleRate?) {
      parts.add('sampleRate=${sampleRate}Hz');
    }
    if (info.audioChannelCount case final channelCount?) {
      parts.add('channels=$channelCount');
    }
    if (info.audioChannelsLabel case final label? when label.isNotEmpty) {
      parts.add('layout=$label');
    }
    return parts.isEmpty ? 'n/a' : parts.join(', ');
  }

  String audioBitrateLabel(PlaybackMediaInfo? info) {
    final bitrate = info?.audioBitrateKbps;
    return bitrate == null ? 'n/a' : '${bitrate.toStringAsFixed(0)} kbps';
  }
}
