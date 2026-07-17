import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/services/player_ui_command_runner.dart';

void main() {
  group('PlayerUiCommandRunner', () {
    test('logs the settled play state only after a delayed command', () async {
      final commandCompleter = Completer<void>();
      var isPlaying = false;
      final logs = <String>[];
      final runner = _buildRunner(
        togglePlay: () async {
          await commandCompleter.future;
          isPlaying = true;
        },
        readState: () =>
            PlayerUiCommandSnapshot(isPlaying: isPlaying, volume: 0.5),
        logs: logs,
      );

      final command = runner.togglePlay(origin: PlayerUiCommandOrigin.shortcut);
      await Future<void>.delayed(Duration.zero);

      expect(logs, isEmpty);

      commandCompleter.complete();
      await command;

      expect(logs, ['Shortcut: Play/Pause toggled. Now: PLAYING']);
    });

    test('does not emit a success log when a command fails', () async {
      final commandCompleter = Completer<void>();
      final logs = <String>[];
      final errors = <Object>[];
      final runner = _buildRunner(
        togglePlay: () async {
          await commandCompleter.future;
          throw StateError('player rejected command');
        },
        logs: logs,
        errors: errors,
      );

      final command = runner.togglePlay(origin: PlayerUiCommandOrigin.panel);
      commandCompleter.complete();
      await command;

      expect(logs, ['UI: Play/Pause failed.']);
      expect(logs.where((message) => message.contains('Now:')), isEmpty);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('serializes quickly repeated commands in invocation order', () async {
      final firstCompleter = Completer<void>();
      final secondCompleter = Completer<void>();
      final events = <String>[];
      final logs = <String>[];
      var invocation = 0;
      var isPlaying = false;
      final runner = _buildRunner(
        togglePlay: () async {
          invocation += 1;
          final current = invocation;
          events.add('start$current');
          await (current == 1 ? firstCompleter.future : secondCompleter.future);
          isPlaying = !isPlaying;
          events.add('end$current');
        },
        readState: () =>
            PlayerUiCommandSnapshot(isPlaying: isPlaying, volume: 0.5),
        logs: logs,
      );

      final first = runner.togglePlay(origin: PlayerUiCommandOrigin.shortcut);
      final second = runner.togglePlay(origin: PlayerUiCommandOrigin.shortcut);
      await Future<void>.delayed(Duration.zero);

      expect(events, ['start1']);

      firstCompleter.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(events, ['start1', 'end1', 'start2']);

      secondCompleter.complete();
      await second;

      expect(events, ['start1', 'end1', 'start2', 'end2']);
      expect(logs, [
        'Shortcut: Play/Pause toggled. Now: PLAYING',
        'Shortcut: Play/Pause toggled. Now: PAUSED',
      ]);
    });

    test('volume log reads the value reached by the delayed command', () async {
      final commandCompleter = Completer<void>();
      var volume = 0.4;
      final logs = <String>[];
      final runner = _buildRunner(
        adjustVolume: (delta) async {
          await commandCompleter.future;
          volume += delta;
        },
        readState: () =>
            PlayerUiCommandSnapshot(isPlaying: false, volume: volume),
        logs: logs,
      );

      final command = runner.adjustVolume(
        0.05,
        origin: PlayerUiCommandOrigin.shortcut,
      );
      await Future<void>.delayed(Duration.zero);
      expect(logs, isEmpty);

      commandCompleter.complete();
      await command;

      expect(logs, ['Shortcut: Volume adjusted by +5%. Volume: 45%']);
    });

    test('absolute volume log reports the settled player value', () async {
      var volume = 0.4;
      final logs = <String>[];
      final runner = _buildRunner(
        setVolume: (normalized) async {
          volume = normalized;
        },
        readState: () =>
            PlayerUiCommandSnapshot(isPlaying: false, volume: volume),
        logs: logs,
      );

      await runner.setVolume(0.65, origin: PlayerUiCommandOrigin.panel);

      expect(logs, ['UI: Volume set to 65%']);
    });

    test('stop success is logged only after completion', () async {
      final commandCompleter = Completer<void>();
      final logs = <String>[];
      final runner = _buildRunner(
        stop: () => commandCompleter.future,
        logs: logs,
      );

      final command = runner.stop(origin: PlayerUiCommandOrigin.panel);
      await Future<void>.delayed(Duration.zero);
      expect(logs, isEmpty);

      commandCompleter.complete();
      await command;

      expect(logs, ['UI: Playback stopped.']);
    });
  });
}

PlayerUiCommandRunner _buildRunner({
  PlayerUiCommand? togglePlay,
  PlayerUiCommand? stop,
  PlayerVolumeCommand? adjustVolume,
  PlayerVolumeCommand? setVolume,
  PlayerUiCommandStateReader? readState,
  required List<String> logs,
  List<Object>? errors,
}) {
  return PlayerUiCommandRunner(
    togglePlayCommand: togglePlay ?? () async {},
    stopCommand: stop ?? () async {},
    adjustVolumeCommand: adjustVolume ?? (_) async {},
    setVolumeCommand: setVolume ?? (_) async {},
    readState:
        readState ??
        () => const PlayerUiCommandSnapshot(isPlaying: false, volume: 0.5),
    writeLog: logs.add,
    reportError: (_, error, _) => errors?.add(error),
  );
}
