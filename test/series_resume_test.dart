import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

void main() {
  group('SeriesResumeState', () {
    test('serializes and deserializes JSON', () {
      const original = SeriesResumeState(
        episodeId: 'ep42',
        episodeTitle: 'The Finale',
        streamUrl: 'http://host/series/user/pass/9001/ep42.mp4',
        positionMs: 125000,
        season: 2,
        episodeNum: 8,
      );

      final decoded = SeriesResumeState.fromJson(original.toJson());
      expect(decoded.episodeId, original.episodeId);
      expect(decoded.episodeTitle, original.episodeTitle);
      expect(decoded.streamUrl, original.streamUrl);
      expect(decoded.positionMs, original.positionMs);
      expect(decoded.season, original.season);
      expect(decoded.episodeNum, original.episodeNum);
    });

    test('label includes season and episode when available', () {
      const state = SeriesResumeState(
        episodeId: '1',
        episodeTitle: 'Pilot',
        streamUrl: 'http://example.com/1.mp4',
        positionMs: 1000,
        season: 1,
        episodeNum: 1,
      );
      expect(state.label, 'S01E01 — Pilot');
    });

    test('label falls back to episode title', () {
      const state = SeriesResumeState(
        episodeId: '1',
        episodeTitle: 'Single File',
        streamUrl: 'http://example.com/show.mp4',
        positionMs: 500,
      );
      expect(state.label, 'Single File');
    });
  });

  group('AppStateRepository series resume key', () {
    test('builds stable key from playlist and stream id', () {
      expect(
        AppStateRepository.seriesResumeKey(7, '9001'),
        'series_resume_7_9001',
      );
    });
  });
}
