import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_assist.dart';

void main() {
  group('media segments', () {
    test('validates ticks and recognizes standard types', () {
      final segment = JellyfinMediaSegment.fromJson({
        'Id': 'intro-1',
        'Type': 'Intro',
        'StartTicks': 10000000,
        'EndTicks': 30000000,
      });
      expect(segment?.type, JellyfinMediaSegmentType.intro);
      expect(segment?.start, const Duration(seconds: 1));
      expect(segment?.end, const Duration(seconds: 3));
      expect(segment?.contains(const Duration(seconds: 2)), isTrue);
      expect(segment?.contains(const Duration(seconds: 3)), isFalse);
    });

    test('rejects empty and reversed ranges', () {
      expect(
        JellyfinMediaSegment.fromJson({
          'Type': 'Recap',
          'StartTicks': 20,
          'EndTicks': 20,
        }),
        isNull,
      );
    });
  });

  group('trickplay geometry', () {
    const resolution = JellyfinTrickplayResolution(
      width: 320,
      height: 180,
      tileColumns: 4,
      tileRows: 3,
      thumbnailCount: 30,
      interval: Duration(seconds: 10),
    );

    test('maps time to tile, row and column', () {
      final frame = JellyfinTrickplayFrame.calculate(
        resolution,
        const Duration(seconds: 170),
      );
      expect(frame?.tileIndex, 1);
      expect(frame?.row, 1);
      expect(frame?.column, 1);
    });

    test('clamps beyond last thumbnail', () {
      final frame = JellyfinTrickplayFrame.calculate(
        resolution,
        const Duration(hours: 1),
      );
      expect(frame?.tileIndex, 2);
      expect(frame?.timestamp, const Duration(seconds: 290));
    });

    test('selects the smallest sufficient resolution', () {
      const manifest = JellyfinTrickplayManifest(
        mediaSourceId: 'source',
        resolutions: [
          JellyfinTrickplayResolution(
            width: 640,
            height: 360,
            tileColumns: 1,
            tileRows: 1,
            thumbnailCount: 1,
            interval: Duration(seconds: 1),
          ),
          resolution,
        ],
      );
      expect(manifest.bestResolution(targetWidth: 240)?.width, 320);
    });
  });

  test('tile cache retains only the two most recently used entries', () {
    final cache = JellyfinTrickplayTileCache<Uint8List>();
    cache.put('a', Uint8List.fromList([1]));
    cache.put('b', Uint8List.fromList([2]));
    expect(cache.get('a'), isNotNull);
    cache.put('c', Uint8List.fromList([3]));
    expect(cache.get('b'), isNull);
    expect(cache.get('a'), isNotNull);
    expect(cache.get('c'), isNotNull);
  });

  test('tile cache releases evicted, replaced and cleared entries', () {
    final released = <Uint8List>[];
    final cache = JellyfinTrickplayTileCache<Uint8List>(
      capacity: 1,
      onEvicted: released.add,
    );
    final first = Uint8List.fromList([1]);
    final replacement = Uint8List.fromList([2]);
    final last = Uint8List.fromList([3]);

    cache.put('tile', first);
    cache.put('tile', replacement);
    cache.put('next', last);
    cache.clear();

    expect(released, [first, replacement, last]);
  });
}
