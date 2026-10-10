import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/desktop_fullscreen.dart';

void main() {
  test(
    'prepares before resize and fits afterwards, restoring on exit',
    () async {
      var enabled = false;
      final calls = <String>[];
      final controller = DesktopFullscreenController(
        readEnabled: () async => enabled,
        prepare: (value) async => calls.add('prepare $value'),
        setEnabledOnWindow: (value) async {
          calls.add('window $value');
          enabled = value;
        },
        finish: (value) async => calls.add('finish $value'),
      );
      await controller.setEnabled(true);
      await controller.setEnabled(false);
      expect(calls, [
        'prepare true',
        'window true',
        'finish true',
        'prepare false',
        'window false',
        'finish false',
      ]);
    },
  );

  test(
    'a failed fit rolls back state and permits another transition',
    () async {
      var enabled = false;
      var fail = true;
      final calls = <String>[];
      final controller = DesktopFullscreenController(
        readEnabled: () async => enabled,
        prepare: (value) async => calls.add('prepare $value'),
        setEnabledOnWindow: (value) async {
          calls.add('window $value');
          enabled = value;
        },
        finish: (value) async {
          calls.add('finish $value');
          if (value && fail) throw StateError('fit failed');
        },
      );
      await expectLater(controller.setEnabled(true), throwsStateError);
      expect(enabled, isFalse);
      expect(calls.sublist(3), [
        'prepare false',
        'window false',
        'finish false',
      ]);
      fail = false;
      await controller.setEnabled(true);
      expect(enabled, isTrue);
    },
  );

  test('shell and Jellyfin requests run sequentially', () async {
    var enabled = false;
    final gate = Completer<void>();
    final started = Completer<void>();
    final calls = <bool>[];
    final controller = DesktopFullscreenController(
      readEnabled: () async => enabled,
      prepare: (_) async {},
      setEnabledOnWindow: (value) async {
        calls.add(value);
        if (value) {
          started.complete();
          await gate.future;
        }
        enabled = value;
      },
      finish: (_) async {},
    );
    final enter = controller.setEnabled(true);
    await started.future;
    final exit = controller.setEnabled(false);
    expect(calls, [true]);
    gate.complete();
    await Future.wait([enter, exit]);
    expect(calls, [true, false]);
    expect(enabled, isFalse);
  });

  test('redundant exit never restores an unsaved window placement', () async {
    final controller = DesktopFullscreenController(
      readEnabled: () async => false,
      prepare: (_) async => fail('unexpected prepare'),
      setEnabledOnWindow: (_) async => fail('unexpected transition'),
      finish: (_) async => fail('unexpected restore'),
    );
    await controller.setEnabled(false);
  });
}
