import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/vod/vod_main_video_surface_gate.dart';

void main() {
  group('waitForVodMainVideoSurface', () {
    test('returns true when the surface is already ready', () async {
      final ready = await waitForVodMainVideoSurface(
        () => true,
        timeout: const Duration(milliseconds: 20),
      );

      expect(ready, isTrue);
    });

    test('returns false when the surface does not become ready', () async {
      var elapsedMs = 0;
      final base = DateTime(2026);

      final ready = await waitForVodMainVideoSurface(
        () => false,
        timeout: const Duration(milliseconds: 5),
        pollInterval: const Duration(milliseconds: 1),
        now: () => base.add(Duration(milliseconds: elapsedMs)),
        delay: (duration) {
          elapsedMs += duration.inMilliseconds;
          return Future<void>.value();
        },
      );

      expect(ready, isFalse);
    });
  });
}
