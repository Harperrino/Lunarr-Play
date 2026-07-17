import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';

Channel _channel({int id = 1, String name = 'RTL HD', String? tvgId}) {
  return Channel(
    id: id,
    playlistId: 1,
    streamId: null,
    name: name,
    logo: null,
    groupName: 'German TV',
    tvgId: tvgId,
    streamUrl: 'http://example.com/rtl.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpgMatchingService', () {
    const knownIds = {'de.rtl', 'us.cnn', 'uk.bbcone'};

    test('matches exact tvgId (trimmed, case-sensitive)', () {
      final channel = _channel(tvgId: 'de.rtl');

      expect(
        EpgMatchingService.resolveEpgChannelId(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        'de.rtl',
      );
      expect(
        EpgMatchingService.classifyMatch(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        EpgMatchStatus.matched,
      );
    });

    test('matches tvgId case-insensitively', () {
      final channel = _channel(name: 'Premium News', tvgId: 'DE.RTL');

      expect(
        EpgMatchingService.resolveEpgChannelId(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        'de.rtl',
      );
      expect(
        EpgMatchingService.classifyMatch(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        EpgMatchStatus.matched,
      );
    });

    test('matches via XMLTV display name', () {
      final channel = _channel(name: 'RTL HD', tvgId: null);

      expect(
        EpgMatchingService.resolveEpgChannelId(
          channel: channel,
          knownEpgChannelIds: knownIds,
          displayNamesByChannelId: const {
            'de.rtl': ['RTL HD'],
          },
        ),
        'de.rtl',
      );
    });

    test(
      'memoizes identical fallback-heavy signatures within one matching index',
      () {
        final index = EpgMatchingIndex(
          knownEpgChannelIds: knownIds,
          displayNamesByChannelId: const {
            'de.rtl': ['RTL HD'],
          },
        );

        final first = index.matchChannel(
          _channel(id: 1, name: 'DE: RTL HD', tvgId: null),
        );
        final second = index.matchChannel(
          _channel(id: 2, name: 'DE: RTL HD', tvgId: null),
        );

        expect(first.matchStatus, EpgMatchStatus.matched);
        expect(first.resolvedEpgChannelId, 'de.rtl');
        expect(second.matchStatus, first.matchStatus);
        expect(second.resolvedEpgChannelId, first.resolvedEpgChannelId);
        expect(index.memoizedMatchCount, 1);
      },
    );

    test('falls back to normalized channel name (RTL HD ↔ de.rtl)', () {
      final channel = _channel(name: 'RTL HD', tvgId: 'wrong.id');

      expect(
        EpgMatchingService.resolveEpgChannelId(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        'de.rtl',
      );
      expect(
        EpgMatchingService.classifyMatch(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        EpgMatchStatus.matched,
      );
    });

    test('returns noTvgId when channel has no tvgId and no name match', () {
      final channel = _channel(name: 'Unknown Station', tvgId: null);

      expect(
        EpgMatchingService.classifyMatch(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        EpgMatchStatus.noTvgId,
      );
    });

    test(
      'returns noMatch when tvgId present but not in EPG and name fails',
      () {
        final channel = _channel(name: 'Mystery Channel', tvgId: 'xx.unknown');

        expect(
          EpgMatchingService.classifyMatch(
            channel: channel,
            knownEpgChannelIds: knownIds,
          ),
          EpgMatchStatus.noMatch,
        );
      },
    );

    test('normalizeName strips special characters', () {
      expect(EpgMatchingService.normalizeName('  RTL HD!  '), 'rtlhd');
      expect(EpgMatchingService.normalizeName('de.rtl'), 'dertl');
    });
  });

  group('EPG matching + repository integration', () {
    late AppDatabase db;
    late EpgRepository epgRepository;

    setUp(() async {
      db = AppDatabase.executor(NativeDatabase.memory());
      epgRepository = EpgRepository(db);

      final now = DateTime.now();
      await epgRepository.syncEpgEntries(
        entries: [
          ParsedEpgEntry(
            channelId: 'de.rtl',
            title: 'RTL Aktuell Live',
            startTime: now.subtract(const Duration(minutes: 10)),
            endTime: now.add(const Duration(minutes: 50)),
          ),
        ],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('resolves tvgId match and returns current programme', () async {
      const knownIds = {'de.rtl'};
      final channel = _channel(id: 7, name: 'RTL HD', tvgId: 'de.rtl');

      expect(
        EpgMatchingService.classifyMatch(
          channel: channel,
          knownEpgChannelIds: knownIds,
        ),
        EpgMatchStatus.matched,
      );

      final resolvedId = EpgMatchingService.resolveEpgChannelId(
        channel: channel,
        knownEpgChannelIds: knownIds,
      );
      expect(resolvedId, 'de.rtl');

      final program = await epgRepository.getCurrentProgram(
        resolvedId!,
        DateTime.now(),
      );
      expect(program, isNotNull);
      expect(program!.title, 'RTL Aktuell Live');
      expect(program.channelId, 'de.rtl');
    });
  });
}
