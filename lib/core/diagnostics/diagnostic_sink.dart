import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';

/// Neutral write boundary for playback diagnostics.
///
/// Player code emits safe diagnostic events and text through this contract;
/// it does not know which UI, history, or feature consumes them.
abstract interface class DiagnosticSink {
  StreamingDiagnosticsSettings get streamingSettings;

  void recordStreaming(StreamingDiagnosticEvent event);

  void addText(String message);
}
