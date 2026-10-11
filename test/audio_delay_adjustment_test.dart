import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/services/audio_delay_adjustment.dart';
import 'package:m3uxtream_player/core/services/audio_delay_session.dart';

class _Native extends Fake implements NativePlayer {
  final properties = <String, String>{
    'pause': 'no',
    'path': 'fixture',
    'time-pos': '40',
    'duration': '180',
    'audio-pts': '40',
    'audio-delay': '0',
    'seeking': 'no',
    'cache-pause': 'no',
    'cache-pause-wait': '1',
    'demuxer-readahead-secs': '3',
    'demuxer-max-bytes': '33554432',
  };
  bool transientPath = false;
  bool discardOffset = false;
  int seeks = 0;
  @override
  Future<String> getProperty(
    String property, {
    bool waitForInitialization = true,
  }) async => properties[property] ?? '';
  @override
  Future<void> setProperty(
    String property,
    String value, {
    bool waitForInitialization = true,
  }) async {
    properties[property] = value;
  }

  @override
  Future<void> command(
    List<String> args, {
    bool waitForInitialization = true,
  }) async {
    expect(args, ['seek', '40.0', 'absolute+exact']);
    seeks++;
    if (transientPath) properties['path'] = '';
    if (discardOffset) properties['audio-delay'] = '0';
    // A paused output device may retain the previous audio clock until resume.
    // Its audio-pts remains 40, even though the exact seek has completed.
  }
}

class _Player extends Fake implements Player {
  final native = _Native();
  @override
  PlatformPlayer get platform => native;
  @override
  Future<void> pause() async {
    native.properties['pause'] = 'yes';
  }

  @override
  Future<void> play() async {
    native.properties['pause'] = 'no';
  }
}

void main() {
  for (final offset in [-15000, 15000]) {
    for (final initiallyPaused in [false, true]) {
      test(
        'stale paused audio clock permits $offset ms alignment; paused=$initiallyPaused',
        () async {
          final player = _Player();
          player.native.properties['pause'] = initiallyPaused ? 'yes' : 'no';
          player.native.transientPath = true;
          await alignNativeAudioDelay(
            player,
            offset,
            adjustment: AudioDelayAdjustment(
              isCurrent: () => true,
              isCancelled: () => false,
              report: (_) {},
            ),
            applyOffset: (value) => applyNativeAudioDelay(player, value),
            isLive: false,
            preBufferSeconds: 0,
          ).timeout(const Duration(seconds: 2));
          expect(player.native.seeks, 1);
          expect(
            double.parse(player.native.properties['audio-delay']!),
            offset / 1000,
          );
          expect(player.native.properties['time-pos'], '40');
          expect(
            player.native.properties['pause'],
            initiallyPaused ? 'yes' : 'no',
          );
        },
      );
    }
  }
  test(
    'engine losing an offset on seek cannot commit a successful correction',
    () async {
      final player = _Player();
      player.native.discardOffset = true;
      final session = AudioDelaySession(
        apply: (value) => applyNativeAudioDelay(player, value),
        adjust: (value, context) => alignNativeAudioDelay(
          player,
          value,
          adjustment: context,
          applyOffset: (next) => applyNativeAudioDelay(player, next),
          isLive: false,
          preBufferSeconds: 0,
        ),
      );
      addTearDown(session.dispose);
      await expectLater(session.setMilliseconds(15000), throwsStateError);
      expect(session.value, 0);
      expect(player.native.properties['pause'], 'no');
    },
  );
}
