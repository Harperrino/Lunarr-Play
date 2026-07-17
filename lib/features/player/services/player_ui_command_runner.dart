/// Identifies the UI surface that initiated a player command.
enum PlayerUiCommandOrigin { panel, shortcut }

/// Minimal player state needed to report the result of a UI command.
class PlayerUiCommandSnapshot {
  const PlayerUiCommandSnapshot({
    required this.isPlaying,
    required this.volume,
  });

  final bool isPlaying;
  final double volume;
}

typedef PlayerUiCommand = Future<void> Function();
typedef PlayerVolumeCommand = Future<void> Function(double value);
typedef PlayerUiCommandStateReader = PlayerUiCommandSnapshot Function();
typedef PlayerUiLogWriter = void Function(String message);
typedef PlayerUiCommandErrorReporter =
    void Function(String command, Object error, StackTrace stackTrace);

/// Serializes player commands initiated by the UI and reports settled state.
///
/// Success logs are intentionally written only after the command future has
/// completed. A failed command produces a neutral failure log and never emits
/// the corresponding success message.
class PlayerUiCommandRunner {
  PlayerUiCommandRunner({
    required this.togglePlayCommand,
    required this.stopCommand,
    required this.adjustVolumeCommand,
    required this.setVolumeCommand,
    required this.readState,
    required this.writeLog,
    required this.reportError,
  });

  final PlayerUiCommand togglePlayCommand;
  final PlayerUiCommand stopCommand;
  final PlayerVolumeCommand adjustVolumeCommand;
  final PlayerVolumeCommand setVolumeCommand;
  final PlayerUiCommandStateReader readState;
  final PlayerUiLogWriter writeLog;
  final PlayerUiCommandErrorReporter reportError;

  Future<void> _pending = Future<void>.value();

  Future<void> togglePlay({required PlayerUiCommandOrigin origin}) {
    return _enqueue(
      commandName: 'Play/Pause',
      origin: origin,
      execute: togglePlayCommand,
      successMessage: () {
        final isPlaying = readState().isPlaying;
        final action = origin == PlayerUiCommandOrigin.panel
            ? 'clicked'
            : 'toggled';
        return '${_prefix(origin)}: Play/Pause $action. Now: '
            '${isPlaying ? 'PLAYING' : 'PAUSED'}';
      },
    );
  }

  Future<void> stop({required PlayerUiCommandOrigin origin}) {
    return _enqueue(
      commandName: 'Stop',
      origin: origin,
      execute: stopCommand,
      successMessage: () => '${_prefix(origin)}: Playback stopped.',
    );
  }

  Future<void> adjustVolume(
    double delta, {
    required PlayerUiCommandOrigin origin,
  }) {
    return _enqueue(
      commandName: 'Volume adjustment',
      origin: origin,
      execute: () => adjustVolumeCommand(delta),
      successMessage: () {
        final volume = readState().volume;
        final signedDelta = '${delta > 0 ? '+' : ''}${(delta * 100).toInt()}%';
        return '${_prefix(origin)}: Volume adjusted by $signedDelta. '
            'Volume: ${(volume * 100).toInt()}%';
      },
    );
  }

  Future<void> setVolume(
    double normalized, {
    required PlayerUiCommandOrigin origin,
  }) {
    return _enqueue(
      commandName: 'Volume change',
      origin: origin,
      execute: () => setVolumeCommand(normalized),
      successMessage: () {
        final volume = readState().volume;
        return '${_prefix(origin)}: Volume set to '
            '${(volume * 100).toInt()}%';
      },
    );
  }

  Future<void> _enqueue({
    required String commandName,
    required PlayerUiCommandOrigin origin,
    required PlayerUiCommand execute,
    required String Function() successMessage,
  }) {
    final execution = _pending.then((_) async {
      try {
        await execute();
        writeLog(successMessage());
      } catch (error, stackTrace) {
        writeLog('${_prefix(origin)}: $commandName failed.');
        reportError(commandName, error, stackTrace);
      }
    });

    // Errors are consumed above so a failed command cannot poison the queue.
    _pending = execution;
    return execution;
  }

  String _prefix(PlayerUiCommandOrigin origin) {
    return switch (origin) {
      PlayerUiCommandOrigin.panel => 'UI',
      PlayerUiCommandOrigin.shortcut => 'Shortcut',
    };
  }
}
