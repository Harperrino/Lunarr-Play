import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/services/audio_delay_session.dart';

class _NativePlayer extends Fake implements NativePlayer {
  final properties = <String, String>{};
  String? reportedValue;

  @override
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    properties[property] = value;
  }

  @override
  Future<String> getProperty(
    String property, {
    bool waitForInitialization = true,
  }) async => reportedValue ?? properties[property] ?? '';
}

class _Player extends Fake implements Player {
  _Player(this.native);
  final _NativePlayer native;
  @override
  PlatformPlayer get platform => native;
}

void main() {
  test('milliseconds map to signed mpv seconds', () async {
    final native = _NativePlayer();
    final player = _Player(native);
    await applyNativeAudioDelay(player, 250);
    expect(native.properties['audio-delay'], '0.25');
    await applyNativeAudioDelay(player, -350);
    expect(native.properties['audio-delay'], '-0.35');
    await applyNativeAudioDelay(player, 0);
    expect(native.properties['audio-delay'], '0.0');
    await applyNativeAudioDelay(player, -60000);
    expect(native.properties['audio-delay'], '-60.0');
    await applyNativeAudioDelay(player, 60000);
    expect(native.properties['audio-delay'], '60.0');
  });

  test(
    'an ignored or unreadable native offset is reported as a failure',
    () async {
      final native = _NativePlayer();
      final player = _Player(native);
      for (final reported in ['0', '', 'NaN', 'Infinity']) {
        native.reportedValue = reported;
        await expectLater(
          applyNativeAudioDelay(player, -5000),
          throwsStateError,
        );
      }
    },
  );

  test('reconnection preserves offset; new source and stop reset it', () async {
    final writes = <int>[];
    final session = AudioDelaySession(
      apply: (value) async => writes.add(value),
    );
    addTearDown(session.dispose);
    await session.beginPlayback(('channel-1', 'url'));
    await session.setMilliseconds(-200);
    await session.beginPlayback(('channel-1', 'url'));
    expect(session.value, -200);
    expect(writes.last, -200);
    await session.beginPlayback(('channel-2', 'url'));
    expect(session.value, 0);
    expect(writes.last, 0);
    await session.setMilliseconds(100);
    await session.beginPlayback(null);
    expect(session.value, 0);
  });

  test('a source change supersedes queued and in-flight adjustments', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final writes = <int>[];
    final session = AudioDelaySession(
      apply: (value) async {
        writes.add(value);
        if (value == 200) {
          started.complete();
          await gate.future;
        }
      },
    );
    addTearDown(session.dispose);
    await session.beginPlayback('first');
    final first = session.setMilliseconds(200);
    await started.future;
    final stale = session.setMilliseconds(400);
    final next = session.beginPlayback('second');
    gate.complete();
    await Future.wait([first, stale, next]);
    expect(writes, [0, 200, 0]);
    expect(session.value, 0);
  });

  test(
    'reapply waits for the last adjustment instead of restoring a stale value',
    () async {
      final writes = <int>[];
      final session = AudioDelaySession(
        apply: (value) async => writes.add(value),
      );
      addTearDown(session.dispose);
      await session.beginPlayback('first');
      await Future.wait([session.setMilliseconds(250), session.reapply()]);
      expect(writes, [0, 250, 250]);
    },
  );

  test(
    'failed write preserves value and does not poison subsequent commands',
    () async {
      final session = AudioDelaySession(
        apply: (value) async {
          if (value == 100) throw StateError('failed');
        },
      );
      addTearDown(session.dispose);
      await session.beginPlayback('first');
      await expectLater(session.setMilliseconds(100), throwsStateError);
      expect(session.value, 0);
      await session.setMilliseconds(-100);
      expect(session.value, -100);
      await session.setMilliseconds(5000);
      expect(session.value, 5000);
      await session.setMilliseconds(65000);
      expect(session.value, AudioDelaySession.maximumMs);
      await session.setMilliseconds(-65000);
      expect(session.value, AudioDelaySession.minimumMs);
    },
  );

  test('disposal discards pending adjustments', () async {
    final writes = <int>[];
    final session = AudioDelaySession(
      apply: (value) async => writes.add(value),
    );
    final pending = session.setMilliseconds(250);
    session.dispose();
    await pending;
    expect(writes, isEmpty);
  });
}
