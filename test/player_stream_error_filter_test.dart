import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

void main() {
  test('ignores renderer style warnings but keeps open errors actionable', () {
    expect(
      isIgnorablePlayerStreamError(
        'failed to initialize video output renderer',
      ),
      isTrue,
    );

    expect(isIgnorablePlayerStreamError('failed to open file'), isFalse);
  });

  test(
    'treats late live open errors as ignorable only after confirmed playback',
    () {
      final now = DateTime.now();

      expect(
        isIgnorableLateSuccessfulLiveOpenError(
          'Failed to open http://example.com/live/u/p/123',
          playbackUri: 'http://example.com/live/u/p/123',
          isSeekable: false,
          hasConfirmedPlayback: true,
          successfulOpenAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isTrue,
      );

      expect(
        isIgnorableLateSuccessfulLiveOpenError(
          'Failed to open http://example.com/live/u/p/123',
          playbackUri: 'http://example.com/live/u/p/123',
          isSeekable: false,
          hasConfirmedPlayback: false,
          successfulOpenAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    },
  );

  test(
    'ignores stale live open errors when the active playback URI has changed',
    () {
      expect(
        isIgnorableStaleLiveOpenError(
          'Failed to open http://example.com/live/u/p/old',
          currentPlaybackUri: 'http://example.com/live/u/p/new',
        ),
        isTrue,
      );

      expect(
        isIgnorableStaleLiveOpenError(
          'Failed to open http://example.com/live/u/p/new',
          currentPlaybackUri: 'http://example.com/live/u/p/new',
        ),
        isFalse,
      );
    },
  );
}
