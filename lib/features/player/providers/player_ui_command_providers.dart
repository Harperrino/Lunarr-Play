import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/services/player_ui_command_runner.dart';

final playerUiCommandRunnerProvider = Provider<PlayerUiCommandRunner>((ref) {
  return PlayerUiCommandRunner(
    togglePlayCommand: () =>
        ref.read(playerNotifierProvider.notifier).togglePlay(),
    stopCommand: () => ref.read(playerNotifierProvider.notifier).stopStream(),
    adjustVolumeCommand: (delta) =>
        ref.read(playerNotifierProvider.notifier).adjustVolume(delta),
    setVolumeCommand: (normalized) => ref
        .read(playerNotifierProvider.notifier)
        .setVolumeNormalized(normalized),
    readState: () {
      final state = ref.read(playerNotifierProvider).valueOrNull;
      return PlayerUiCommandSnapshot(
        isPlaying: state?.player.state.playing ?? false,
        volume: (state?.player.state.volume ?? 0) / 100,
      );
    },
    writeLog: ref.read(uiLogsProvider.notifier).addLog,
    reportError: (command, error, stackTrace) {
      AppLogger.error(
        'PlayerUiCommandRunner: $command command failed',
        error,
        stackTrace,
      );
    },
  );
});
