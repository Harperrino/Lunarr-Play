import 'package:flutter_test/flutter_test.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';

import 'package:m3uxtream_player/core/services/epg_matching_service.dart';

import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/controllers/epg_scroll_coordinator.dart';

Channel _channel({
  int id = 1,

  String name = 'RTL HD',

  String? tvgId,

  String channelType = 'live',
}) {
  return Channel(
    id: id,

    playlistId: 1,

    streamId: null,

    name: name,

    logo: null,

    groupName: 'German TV',

    tvgId: tvgId,

    streamUrl: 'http://example.com/stream.m3u8',

    isFavorite: false,
    isWatchLater: false,

    channelType: channelType,

    lastWatchedPosition: null,

    duration: null,

    lastWatchedAt: null,
  );
}

EpgEntry _entry({
  required String channelId,

  required String title,

  required DateTime start,

  required DateTime end,
}) {
  return EpgEntry(
    id: channelId.hashCode,

    channelId: channelId,

    title: title,

    description: null,

    startTime: start,

    endTime: end,
  );
}

void main() {
  group('EPG grid providers (pure logic)', () {
    final windowStart = DateTime(2025, 6, 1, 0);

    final windowEnd = windowStart.add(const Duration(hours: 4));

    test('groupEpgEntriesByChannelId groups and sorts programmes', () {
      final entries = [
        _entry(
          channelId: 'de.rtl',

          title: 'Late News',

          start: windowStart.add(const Duration(hours: 2)),

          end: windowStart.add(const Duration(hours: 3)),
        ),

        _entry(
          channelId: 'de.rtl',

          title: 'Morning Show',

          start: windowStart.add(const Duration(hours: 1)),

          end: windowStart.add(const Duration(hours: 2)),
        ),

        _entry(
          channelId: 'us.cnn',

          title: 'CNN News',

          start: windowStart,

          end: windowStart.add(const Duration(hours: 1)),
        ),
      ];

      final grouped = groupEpgEntriesByChannelId(entries);

      expect(grouped.keys, containsAll(['de.rtl', 'us.cnn']));

      expect(grouped['de.rtl']!.map((e) => e.title), [
        'Morning Show',
        'Late News',
      ]);
    });

    test('programsForResolvedId matches case-insensitively', () {
      final data = groupEpgEntriesByChannelId([
        _entry(
          channelId: 'DE.RTL',

          title: 'RTL Aktuell',

          start: windowStart,

          end: windowStart.add(const Duration(hours: 1)),
        ),
      ]);

      expect(programsForResolvedId(data, 'de.rtl').single.title, 'RTL Aktuell');
    });

    test('buildEpgGridRows maps programmes by channel db id', () {
      final channel = _channel(id: 42, tvgId: 'de.rtl');

      final program = _entry(
        channelId: 'de.rtl',

        title: 'RTL Aktuell',

        start: windowStart,

        end: windowStart.add(const Duration(hours: 1)),
      );

      final rows = buildEpgGridRows(
        channels: [channel],

        epgData: groupEpgEntriesByChannelId([program]),

        channelMatches: buildChannelMatches(
          channels: [channel],
          knownEpgChannelIds: const {'de.rtl'},
        ),
      );

      expect(rows.length, 1);

      expect(rows.first.resolvedEpgChannelId, 'de.rtl');

      expect(rows.first.matchStatus, EpgMatchStatus.matched);

      expect(rows.first.programs.single.title, 'RTL Aktuell');
    });

    test('DE: 3sat HD matches XMLTV id via name token fallback', () {
      const knownIds = {'3sat.de', 'ard.de'};

      final channel = _channel(name: 'DE: 3sat HD', tvgId: 'wrong.id');

      expect(
        EpgMatchingService.resolveEpgChannelId(
          channel: channel,

          knownEpgChannelIds: knownIds,

          displayNamesByChannelId: const {
            '3sat.de': ['3sat'],
          },
        ),

        '3sat.de',
      );
    });

    test(
      'epgEntriesForGridDisplay removes staggered overlapping duplicates',
      () {
        final day = DateTime(2026, 6, 2);
        final overlapping = [
          _entry(
            channelId: '34',
            title: 'AEW: Collision',
            start: day.add(const Duration(hours: 0, minutes: 20)),
            end: day.add(const Duration(hours: 1, minutes: 15)),
          ),
          _entry(
            channelId: '34',
            title: 'AEW: Collision',
            start: day.add(const Duration(hours: 0, minutes: 28)),
            end: day.add(const Duration(hours: 1, minutes: 20)),
          ),
          _entry(
            channelId: '34',
            title: 'AEW: Collision',
            start: day.add(const Duration(hours: 1, minutes: 15)),
            end: day.add(const Duration(hours: 3)),
          ),
          _entry(
            channelId: '34',
            title: 'AEW: Collision',
            start: day.add(const Duration(hours: 1, minutes: 20)),
            end: day.add(const Duration(hours: 3, minutes: 10)),
          ),
        ];

        final deduped = epgEntriesForGridDisplay(overlapping);

        expect(deduped, hasLength(2));
        expect(deduped.first.title, 'AEW: Collision');
        expect(deduped.first.startTime, overlapping.first.startTime);
        expect(deduped.last.startTime, overlapping[2].startTime);
      },
    );

    test('epgProgrammeLayout clips programme starting before window', () {
      final entry = _entry(
        channelId: '3sat.de',

        title: 'Nachtprogramm',

        start: windowStart.subtract(const Duration(hours: 2)),

        end: windowStart.add(const Duration(hours: 1)),
      );

      final layout = epgProgrammeLayout(
        windowStart: windowStart,

        windowEnd: windowEnd,

        entry: entry,
      );

      expect(layout.left, 0);

      expect(layout.width, greaterThan(0));
    });

    test('channel without match has empty programmes', () {
      final rows = buildEpgGridRows(
        channels: [_channel(name: 'Unknown', tvgId: null)],

        epgData: const {},

        channelMatches: buildChannelMatches(
          channels: [_channel(name: 'Unknown', tvgId: null)],
          knownEpgChannelIds: const {'de.rtl'},
        ),
      );

      expect(rows.first.matchStatus, EpgMatchStatus.noTvgId);

      expect(rows.first.programs, isEmpty);
    });

    test('currentProgramAt finds airing programme', () {
      final now = windowStart.add(const Duration(hours: 1, minutes: 30));
      final programs = [
        _entry(
          channelId: '3sat.de',
          title: 'Dokumentation',
          start: windowStart.add(const Duration(hours: 1)),
          end: windowStart.add(const Duration(hours: 2)),
        ),
      ];

      expect(currentProgramAt(programs, now)?.title, 'Dokumentation');
      expect(
        epgGridRowSubtitle(
          EpgGridRowData(
            channel: _channel(name: 'DE: 3sat HD'),
            matchStatus: EpgMatchStatus.matched,
            resolvedEpgChannelId: '3sat.de',
            programs: programs,
          ),
          now,
        ),
        'Jetzt: Dokumentation',
      );
    });

    test('epgGridTimeToOffset and timeline width scale with window', () {
      expect(
        epgGridTimeToOffset(
          windowStart,
          windowStart.add(const Duration(hours: 2)),
        ),
        2 * 60 * epgGridPixelsPerMinute,
      );
      expect(
        epgGridTimelineWidth(windowStart, windowEnd),
        4 * 60 * epgGridPixelsPerMinute,
      );
    });

    test(
      'epgGridMinuteTickDelay returns the remaining time to the next minute',
      () {
        expect(
          epgGridMinuteTickDelay(DateTime(2026, 6, 10, 12, 34, 0)),
          const Duration(minutes: 1),
        );
        expect(
          epgGridMinuteTickDelay(DateTime(2026, 6, 10, 12, 34, 42, 500)),
          const Duration(seconds: 17, milliseconds: 500),
        );
      },
    );

    test('EPG zoom keeps the same temporal scroll anchor', () {
      expect(EpgScrollCoordinator.scaledOffsetForZoom(240, 4, 6), 360);
      expect(EpgScrollCoordinator.scaledOffsetForZoom(240, 0, 6), 240);
    });
  });
}
