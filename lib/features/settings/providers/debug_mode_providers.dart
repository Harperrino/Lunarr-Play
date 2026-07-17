import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';

/// Persistent app-wide debug mode flag.
final debugModeProvider = AsyncNotifierProvider<DebugModeNotifier, bool>(
  DebugModeNotifier.new,
);

class DebugModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(appStateRepositoryProvider).getDebugModeEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(appStateRepositoryProvider).setDebugModeEnabled(enabled);
    state = AsyncData(enabled);
  }
}
