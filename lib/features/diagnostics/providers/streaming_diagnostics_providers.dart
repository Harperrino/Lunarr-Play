import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';

const _kMaxStreamingDiagnostics = 120;

final streamingDiagnosticsProvider =
    StateNotifierProvider<
      StreamingDiagnosticsNotifier,
      StreamingDiagnosticSnapshot
    >((ref) {
      return StreamingDiagnosticsNotifier();
    });

final streamingDiagnosticsProbeBusyProvider =
    StateNotifierProvider<StreamingDiagnosticsProbeNotifier, bool>((ref) {
      return StreamingDiagnosticsProbeNotifier();
    });

class StreamingDiagnosticsNotifier
    extends StateNotifier<StreamingDiagnosticSnapshot> {
  StreamingDiagnosticsNotifier()
    : super(const StreamingDiagnosticSnapshot(events: []));

  void record(StreamingDiagnosticEvent event) {
    final next = [...state.events, event];
    state = StreamingDiagnosticSnapshot(
      events: next.length > _kMaxStreamingDiagnostics
          ? next.sublist(next.length - _kMaxStreamingDiagnostics)
          : next,
    );
  }

  void clear() {
    state = const StreamingDiagnosticSnapshot(events: []);
  }
}

class StreamingDiagnosticsProbeNotifier extends StateNotifier<bool> {
  StreamingDiagnosticsProbeNotifier() : super(false);

  Future<T?> runExclusive<T>(Future<T> Function() action) async {
    if (state) return null;
    state = true;
    try {
      return await action();
    } finally {
      state = false;
    }
  }
}

final latestStreamingFailureProvider = Provider<StreamingDiagnosticEvent?>((
  ref,
) {
  return ref.watch(streamingDiagnosticsProvider).lastFailure;
});

final streamingDiagnosticsSettingsProvider =
    AsyncNotifierProvider<
      StreamingDiagnosticsSettingsNotifier,
      StreamingDiagnosticsSettings
    >(StreamingDiagnosticsSettingsNotifier.new);

class StreamingDiagnosticsSettingsNotifier
    extends AsyncNotifier<StreamingDiagnosticsSettings> {
  static const defaultAutoFallbackEnabled = true;
  static const defaultShowOnErrorEnabled = true;

  @override
  Future<StreamingDiagnosticsSettings> build() async {
    final repository = ref.read(appStateRepositoryProvider);
    return StreamingDiagnosticsSettings(
      autoFallbackEnabled: await repository.getStreamingAutoFallbackEnabled(
        defaultEnabled: defaultAutoFallbackEnabled,
      ),
      showOnErrorEnabled: await repository.getStreamingShowDiagnosisOnError(
        defaultEnabled: defaultShowOnErrorEnabled,
      ),
    );
  }

  Future<void> setAutoFallbackEnabled(bool enabled) async {
    await ref
        .read(appStateRepositoryProvider)
        .setStreamingAutoFallbackEnabled(enabled);
    final current =
        state.valueOrNull ??
        const StreamingDiagnosticsSettings(
          autoFallbackEnabled: defaultAutoFallbackEnabled,
          showOnErrorEnabled: defaultShowOnErrorEnabled,
        );
    state = AsyncData(
      StreamingDiagnosticsSettings(
        autoFallbackEnabled: enabled,
        showOnErrorEnabled: current.showOnErrorEnabled,
      ),
    );
  }

  Future<void> setShowOnErrorEnabled(bool enabled) async {
    await ref
        .read(appStateRepositoryProvider)
        .setStreamingShowDiagnosisOnError(enabled);
    final current =
        state.valueOrNull ??
        const StreamingDiagnosticsSettings(
          autoFallbackEnabled: defaultAutoFallbackEnabled,
          showOnErrorEnabled: defaultShowOnErrorEnabled,
        );
    state = AsyncData(
      StreamingDiagnosticsSettings(
        autoFallbackEnabled: current.autoFallbackEnabled,
        showOnErrorEnabled: enabled,
      ),
    );
  }
}
