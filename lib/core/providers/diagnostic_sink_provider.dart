import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/diagnostics/diagnostic_sink.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/providers/streaming_diagnostics_providers.dart';
import 'package:m3uxtream_player/core/providers/ui_logs_providers.dart';

final diagnosticSinkProvider = Provider<DiagnosticSink>((ref) {
  return RiverpodDiagnosticSink(ref);
});

class RiverpodDiagnosticSink implements DiagnosticSink {
  const RiverpodDiagnosticSink(this.ref);

  final Ref ref;

  @override
  StreamingDiagnosticsSettings get streamingSettings {
    return ref.read(streamingDiagnosticsSettingsProvider).valueOrNull ??
        const StreamingDiagnosticsSettings(
          autoFallbackEnabled:
              StreamingDiagnosticsSettingsNotifier.defaultAutoFallbackEnabled,
          showOnErrorEnabled:
              StreamingDiagnosticsSettingsNotifier.defaultShowOnErrorEnabled,
        );
  }

  @override
  void recordStreaming(StreamingDiagnosticEvent event) {
    ref.read(streamingDiagnosticsProvider.notifier).record(event);
  }

  @override
  void addText(String message) {
    ref.read(uiLogsProvider.notifier).addLog(message);
  }
}
