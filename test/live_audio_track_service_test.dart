import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/services/live_audio_track_service.dart';

void main() {
  group('LiveAudioTrackService', () {
    test('pickBest prefers AAC over unknown codecs', () {
      const tracks = Tracks(
        video: [],
        audio: [
          AudioTrack('1', null, null, codec: 'unknown'),
          AudioTrack('2', null, 'deu', codec: 'aac'),
        ],
        subtitle: [],
      );

      expect(LiveAudioTrackService.pickBest(tracks)?.id, '2');
    });

    test('validTracks skips auto/no but keeps real tracks', () {
      final tracks = Tracks(
        video: const [],
        audio: [
          AudioTrack.auto(),
          AudioTrack.no(),
          const AudioTrack('bad', null, null, codec: 'none'),
          const AudioTrack('ok', null, null, codec: 'mp2'),
        ],
        subtitle: const [],
      );

      expect(LiveAudioTrackService.validTracks(tracks).map((t) => t.id), [
        'bad',
        'ok',
      ]);
    });

    test('selectableTracks keeps all manual tracks for the menu', () {
      final tracks = Tracks(
        video: const [],
        audio: [
          AudioTrack.auto(),
          AudioTrack.no(),
          const AudioTrack('1', null, null, codec: 'unknown'),
          const AudioTrack('2', null, null, codec: 'aac'),
        ],
        subtitle: const [],
      );

      expect(
        LiveAudioTrackService.selectableTracks(tracks).map((track) => track.id),
        ['1', '2'],
      );
    });

    test('labelFor combines language title codec and channels', () {
      const track = AudioTrack(
        '7',
        'Main',
        'deu',
        codec: 'aac',
        channelscount: 2,
      );

      expect(
        LiveAudioTrackService.labelFor(track, fallbackIndex: 7),
        'Deutsch \u00b7 Main \u00b7 AAC \u00b7 Stereo',
      );
    });

    test('labelFor renders special tracks and EAC3 codecs clearly', () {
      expect(LiveAudioTrackService.labelFor(AudioTrack.auto()), 'Auto');
      expect(LiveAudioTrackService.labelFor(AudioTrack.no()), 'Keine');
      expect(LiveAudioTrackService.isSelectable(AudioTrack.auto()), isFalse);
      expect(LiveAudioTrackService.isSelectable(AudioTrack.no()), isFalse);

      const track = AudioTrack(
        '9',
        'Main',
        'deu',
        codec: 'eac3',
        channelscount: 6,
      );

      expect(
        LiveAudioTrackService.labelFor(track),
        'Deutsch \u00b7 Main \u00b7 E-AC-3 \u00b7 5.1',
      );
      expect(
        LiveAudioTrackService.diagnosticLabelFor(track),
        'id=9 | Deutsch \u00b7 Main \u00b7 E-AC-3 \u00b7 5.1',
      );
      expect(
        LiveAudioTrackService.trackFilterReason(track),
        'kept: real audio track',
      );
    });

    test(
      'pickBest falls back to the first real track when codecs are unknown',
      () {
        final tracks = Tracks(
          video: [],
          audio: [
            AudioTrack.auto(),
            AudioTrack.no(),
            const AudioTrack('1', null, null, codec: 'unknown'),
            const AudioTrack('2', null, null, codec: null),
          ],
          subtitle: [],
        );

        expect(LiveAudioTrackService.pickBest(tracks)?.id, '1');
      },
    );

    test('labelFor falls back to Track N when no metadata is present', () {
      const track = AudioTrack('8', null, null, codec: null);

      expect(
        LiveAudioTrackService.labelFor(track, fallbackIndex: 8),
        'Track 8',
      );
    });

    test('pickBest keeps 5.1 before stereo when preferStereo is false', () {
      const tracks = Tracks(
        video: [],
        audio: [
          AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 6),
          AudioTrack('2', 'Main', 'deu', codec: 'ac3', channelscount: 2),
        ],
        subtitle: [],
      );

      expect(LiveAudioTrackService.pickBest(tracks)?.id, '1');
      expect(
        LiveAudioTrackService.pickBest(tracks, preferStereo: false)?.id,
        '1',
      );
    });

    test('pickBest prefers native stereo track when preferStereo is true', () {
      const tracks = Tracks(
        video: [],
        audio: [
          AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 6),
          AudioTrack('2', 'Main', 'deu', codec: 'ac3', channelscount: 2),
        ],
        subtitle: [],
      );

      expect(
        LiveAudioTrackService.pickBest(tracks, preferStereo: true)?.id,
        '2',
      );
    });

    test('preferStereo beats a language-matching multichannel track', () {
      const candidates = [
        AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 6),
        AudioTrack('2', 'Main', 'eng', codec: 'ac3', channelscount: 2),
      ];

      expect(
        LiveAudioTrackService.pickBestFrom(
          candidates,
          preferStereo: true,
          preferredLanguage: 'de',
        )?.id,
        '2',
      );
    });

    test('isStereoTrack detects stereo by channelscount', () {
      expect(
        LiveAudioTrackService.isStereoTrack(
          const AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 2),
        ),
        isTrue,
      );
      expect(
        LiveAudioTrackService.isStereoTrack(
          const AudioTrack('1', 'Main', 'deu', codec: 'ac3', channelscount: 6),
        ),
        isFalse,
      );
    });

    test('isStereoTrack detects stereo by channels label', () {
      expect(
        LiveAudioTrackService.isStereoTrack(
          const AudioTrack(
            '1',
            'Main',
            'deu',
            codec: 'ac3',
            channels: 'stereo',
          ),
        ),
        isTrue,
      );
      expect(
        LiveAudioTrackService.isStereoTrack(
          const AudioTrack(
            '1',
            'Main',
            'deu',
            codec: 'ac3',
            channels: '5.1(side)',
          ),
        ),
        isFalse,
      );
    });

    test('isStereoTrack excludes auto and no special tracks', () {
      expect(LiveAudioTrackService.isStereoTrack(AudioTrack.auto()), isFalse);
      expect(LiveAudioTrackService.isStereoTrack(AudioTrack.no()), isFalse);
    });

    test(
      'pickBestFrom falls back to codec preference when no stereo track exists',
      () {
        const candidates = [
          AudioTrack('1', 'Main', 'deu', codec: 'mp2', channelscount: 6),
          AudioTrack('2', 'Main', 'deu', codec: 'ac3', channelscount: 6),
        ];

        expect(
          LiveAudioTrackService.pickBestFrom(
            candidates,
            preferStereo: true,
          )?.id,
          '2',
        );
      },
    );

    test('preferred language selects matching track when otherwise equal', () {
      const candidates = [
        AudioTrack('1', 'Main', 'eng', codec: 'aac', channelscount: 2),
        AudioTrack('2', 'Main', 'deu', codec: 'aac', channelscount: 2),
      ];

      expect(
        LiveAudioTrackService.pickBestFrom(
          candidates,
          preferredLanguage: 'de',
        )?.id,
        '2',
      );
    });

    test(
      'preferred language chooses the matching stereo track among stereo candidates',
      () {
        const candidates = [
          AudioTrack('1', 'Main', 'eng', codec: 'aac', channelscount: 2),
          AudioTrack('2', 'Main', 'deu', codec: 'mp2', channelscount: 2),
          AudioTrack('3', 'Main', 'fra', codec: 'ac3', channelscount: 6),
        ];

        expect(
          LiveAudioTrackService.pickBestFrom(
            candidates,
            preferStereo: true,
            preferredLanguage: 'de',
          )?.id,
          '2',
        );
      },
    );

    test('language aliases match canonical codes', () {
      const candidates = [
        AudioTrack('1', 'Main', 'ger', codec: 'aac', channelscount: 2),
        AudioTrack('2', 'Main', 'eng', codec: 'aac', channelscount: 2),
      ];

      expect(
        LiveAudioTrackService.pickBestFrom(
          candidates,
          preferredLanguage: 'Deutsch',
        )?.id,
        '1',
      );
      expect(
        LiveAudioTrackService.pickBestFrom(
          candidates,
          preferredLanguage: 'deu',
        )?.id,
        '1',
      );
    });

    test(
      'preferred language does not override codec preference when languages differ',
      () {
        const candidates = [
          AudioTrack('1', 'Main', 'eng', codec: 'mp2', channelscount: 2),
          AudioTrack('2', 'Main', 'deu', codec: 'aac', channelscount: 2),
        ];

        // Preferred English exists but AAC/Deutsch is a much better codec candidate.
        // Language bonus (100) outweighs codec difference (8 vs 7), so English mp2 wins.
        expect(
          LiveAudioTrackService.pickBestFrom(
            candidates,
            preferredLanguage: 'en',
          )?.id,
          '1',
        );
      },
    );

    test(
      'when no preferred language matches, falls back to codec/stereo logic',
      () {
        const candidates = [
          AudioTrack('1', 'Main', 'fra', codec: 'mp2', channelscount: 2),
          AudioTrack('2', 'Main', 'spa', codec: 'aac', channelscount: 2),
        ];

        expect(
          LiveAudioTrackService.pickBestFrom(
            candidates,
            preferredLanguage: 'de',
          )?.id,
          '2',
        );
      },
    );

    test(
      'when no stereo track exists, preferStereo falls back to normal language and codec scoring',
      () {
        const candidates = [
          AudioTrack('1', 'Main', 'eng', codec: 'aac', channelscount: 6),
          AudioTrack('2', 'Main', 'deu', codec: 'mp2', channelscount: 6),
        ];

        expect(
          LiveAudioTrackService.pickBestFrom(
            candidates,
            preferStereo: true,
            preferredLanguage: 'de',
          )?.id,
          '2',
        );
      },
    );

    test('force stereo and preferred language combine predictably', () {
      const candidates = [
        AudioTrack('1', 'Main', 'eng', codec: 'ac3', channelscount: 6),
        AudioTrack('2', 'Main', 'deu', codec: 'ac3', channelscount: 2),
      ];

      expect(
        LiveAudioTrackService.pickBestFrom(
          candidates,
          preferStereo: true,
          preferredLanguage: 'de',
        )?.id,
        '2',
      );
    });

    test('scoreTrack never promotes auto/no special tracks', () {
      expect(LiveAudioTrackService.scoreTrack(AudioTrack.auto()), lessThan(0));
      expect(LiveAudioTrackService.scoreTrack(AudioTrack.no()), lessThan(0));
    });

    test('canonicalLanguageCode normalizes aliases', () {
      expect(LiveAudioTrackService.canonicalLanguageCode('de'), 'de');
      expect(LiveAudioTrackService.canonicalLanguageCode('deu'), 'de');
      expect(LiveAudioTrackService.canonicalLanguageCode('ger'), 'de');
      expect(LiveAudioTrackService.canonicalLanguageCode('german'), 'de');
      expect(LiveAudioTrackService.canonicalLanguageCode('Deutsch'), 'de');
      expect(LiveAudioTrackService.canonicalLanguageCode('en'), 'en');
      expect(LiveAudioTrackService.canonicalLanguageCode('eng'), 'en');
      expect(LiveAudioTrackService.canonicalLanguageCode('english'), 'en');
      expect(LiveAudioTrackService.canonicalLanguageCode(null), isNull);
      expect(LiveAudioTrackService.canonicalLanguageCode(''), isNull);
    });

    test('auto and no are never chosen as force-stereo candidates', () {
      final candidates = [
        AudioTrack.auto(),
        AudioTrack.no(),
        const AudioTrack('1', 'Main', 'eng', codec: 'ac3', channelscount: 2),
      ];

      expect(
        LiveAudioTrackService.pickBestFrom(
          candidates,
          preferStereo: true,
          preferredLanguage: 'de',
        )?.id,
        '1',
      );
    });
  });
}
