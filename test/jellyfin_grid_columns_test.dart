import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_library_view.dart';

void main() {
  group('jellyfinGridColumnsFor', () {
    test('scales at 1080, 1440 and 4K window content widths', () {
      expect(jellyfinGridColumnsFor(780), 4); // 1080px window minus sidebar/gutters
      expect(jellyfinGridColumnsFor(1080), 5); // 1440px window
      expect(jellyfinGridColumnsFor(2560), 12); // 4K window, capped
    });

    test('never returns fewer than one column', () {
      expect(jellyfinGridColumnsFor(0), 1);
      expect(jellyfinGridColumnsFor(100), 1);
    });

    test('respects a custom minimum card width', () {
      expect(jellyfinGridColumnsFor(780, minCardWidth: 220), 3);
    });
  });
}
