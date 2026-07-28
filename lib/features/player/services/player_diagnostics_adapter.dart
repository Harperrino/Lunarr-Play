import 'package:media_kit/media_kit.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/diagnostics/diagnostic_sink.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/services/player_diagnostics_reporter.dart';

/// Typed boundary between playback orchestration and diagnostic fan-out.
final class PlayerDiagnosticsAdapter {
  const PlayerDiagnosticsAdapter({
    required this.readSink,
    this.reporter = const PlayerDiagnosticsReporter(),
  });

  final DiagnosticSink Function() readSink;
  final PlayerDiagnosticsReporter reporter;

  StreamingDiagnosticsSettings get streamingSettings =>
      readSink().streamingSettings;

  void recordStreaming({
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
    readSink().recordStreaming(
      reporter.createStreamingEvent(
        timestamp: timestamp ?? DateTime.now(),
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

  void logStreamingFailure(String message) {
    readSink().addText(redactStreamText('Streaming: $message'));
  }

  void logAudioWarning(String message) {
    readSink().addText(redactStreamText('Audio: $message'));
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
    reporter.logAudioSnapshot(
      player: player,
      stage: stage,
      rawTracks: rawTracks,
      selectableTracks: selectableTracks,
      forceStereoEnabled: forceStereoEnabled,
      delivery: delivery,
      appliedDemuxerLavfFormat: appliedDemuxerLavfFormat,
      selectedAudioTrackId: selectedAudioTrackId,
      mediaInfo: mediaInfo,
      streamError: streamError,
    );
  }

  String audioParamsLabel(PlaybackMediaInfo? info) =>
      reporter.audioParamsLabel(info);

  String audioBitrateLabel(PlaybackMediaInfo? info) =>
      reporter.audioBitrateLabel(info);
}
