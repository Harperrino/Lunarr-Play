import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/app_shutdown_service.dart';

class _FakeShutdownActions implements AppShutdownActions {
  _FakeShutdownActions({this.snapshot, this.failStep});

  final SeriesResumeSnapshot? snapshot;
  final String? failStep;
  final List<String> calls = <String>[];

  void _maybeFail(String step) {
    if (failStep == step) {
      throw StateError('failed step: $step');
    }
  }

  @override
  Future<void> closeDatabase() async {
    calls.add('closeDatabase');
    _maybeFail('closeDatabase');
  }

  @override
  Future<SeriesResumeSnapshot?> captureSeriesResumeSnapshot() async {
    calls.add('captureSeriesResumeSnapshot');
    _maybeFail('captureSeriesResumeSnapshot');
    return snapshot;
  }

  @override
  Future<void> destroyWindow() async {
    calls.add('destroyWindow');
    _maybeFail('destroyWindow');
  }

  @override
  Future<void> disposePlaybackResources() async {
    calls.add('disposePlaybackResources');
    _maybeFail('disposePlaybackResources');
  }

  @override
  Future<void> exitFullscreenIfNeeded() async {
    calls.add('exitFullscreenIfNeeded');
    _maybeFail('exitFullscreenIfNeeded');
  }

  @override
  Future<void> saveSeriesResume(SeriesResumeSnapshot snapshot) async {
    calls.add('saveSeriesResume:${snapshot.positionMs}');
    _maybeFail('saveSeriesResume');
  }

  @override
  Future<void> stopPlayback() async {
    calls.add('stopPlayback');
    _maybeFail('stopPlayback');
  }
}

void main() {
  test('shutdown is idempotent and runs each step once', () async {
    final actions = _FakeShutdownActions(
      snapshot: const SeriesResumeSnapshot(
        playlistId: 7,
        seriesStreamId: 'series-7',
        seriesChannelDbId: 42,
        episodeId: 'ep-1',
        episodeTitle: 'Episode 1',
        streamUrl: 'https://example.com/series/ep1',
        positionMs: 12345,
        season: 1,
        episodeNum: 1,
      ),
    );
    final controller = AppShutdownController(actions);

    await Future.wait([
      controller.requestShutdown(reason: 'titlebar close'),
      controller.requestShutdown(reason: 'window close'),
    ]);

    expect(actions.calls, [
      'captureSeriesResumeSnapshot',
      'exitFullscreenIfNeeded',
      'stopPlayback',
      'saveSeriesResume:12345',
      'disposePlaybackResources',
      'closeDatabase',
      'destroyWindow',
    ]);
  });

  test('shutdown continues after a failed step', () async {
    final actions = _FakeShutdownActions(
      snapshot: const SeriesResumeSnapshot(
        playlistId: 7,
        seriesStreamId: 'series-7',
        seriesChannelDbId: 42,
        episodeId: 'ep-1',
        episodeTitle: 'Episode 1',
        streamUrl: 'https://example.com/series/ep1',
        positionMs: 12345,
      ),
      failStep: 'stopPlayback',
    );
    final controller = AppShutdownController(actions);

    await controller.requestShutdown(reason: 'window close');

    expect(actions.calls, [
      'captureSeriesResumeSnapshot',
      'exitFullscreenIfNeeded',
      'stopPlayback',
      'saveSeriesResume:12345',
      'disposePlaybackResources',
      'closeDatabase',
      'destroyWindow',
    ]);
  });
}
