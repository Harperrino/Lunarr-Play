import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';

void main() {
  test('exposes the expected live startup buffer options', () {
    expect(liveStartupBufferSecondsOptions, [0, 5, 10, 20, 30, 45, 60, 120]);
  });

  test('labels live startup buffer options correctly', () {
    expect(labelForLiveStartupBufferSeconds(0), 'Aus');
    expect(labelForLiveStartupBufferSeconds(5), '5 Sekunden');
    expect(labelForLiveStartupBufferSeconds(120), '120 Sekunden (maximal)');
  });

  test('normalizes stored seconds to the closest allowed option', () {
    expect(normalizeLiveStartupBufferSeconds(0), 0);
    expect(normalizeLiveStartupBufferSeconds(2), 0);
    expect(normalizeLiveStartupBufferSeconds(3), 5);
    expect(normalizeLiveStartupBufferSeconds(5), 5);
    expect(normalizeLiveStartupBufferSeconds(8), 10);
    expect(normalizeLiveStartupBufferSeconds(15), 10);
    expect(normalizeLiveStartupBufferSeconds(25), 20);
    expect(normalizeLiveStartupBufferSeconds(38), 45);
    expect(normalizeLiveStartupBufferSeconds(60), 60);
    expect(normalizeLiveStartupBufferSeconds(90), 60);
    expect(normalizeLiveStartupBufferSeconds(200), 120);
  });

  test('calculates a bounded live startup timeout', () {
    expect(liveStartupBufferTimeoutForSeconds(0), Duration.zero);
    expect(liveStartupBufferTimeoutForSeconds(5), const Duration(seconds: 15));
    expect(liveStartupBufferTimeoutForSeconds(10), const Duration(seconds: 20));
    expect(liveStartupBufferTimeoutForSeconds(20), const Duration(seconds: 30));
    expect(liveStartupBufferTimeoutForSeconds(60), const Duration(seconds: 70));
    expect(
      liveStartupBufferTimeoutForSeconds(120),
      const Duration(seconds: 130),
    );
  });

  test('maps off live startup buffering to a small technical read-ahead', () {
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(0), 3);
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(2), 3);
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(5), 5);
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(60), 60);
    expect(liveTechnicalReadAheadSecondsForStartupSeconds(120), 120);
  });
}
