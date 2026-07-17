import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpgRepository', () {
    late AppDatabase db;
    late EpgRepository repository;

    setUp(() {
      db = AppDatabase.executor(NativeDatabase.memory());
      repository = EpgRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedEntries() async {
      await repository.syncEpgEntries(
        entries: [
          ParsedEpgEntry(
            channelId: 'de.rtl',
            title: 'Morning Show',
            startTime: DateTime.utc(2030, 5, 21, 6, 0),
            endTime: DateTime.utc(2030, 5, 21, 7, 0),
          ),
          ParsedEpgEntry(
            channelId: 'de.rtl',
            title: 'RTL Aktuell',
            startTime: DateTime.utc(2030, 5, 21, 12, 0),
            endTime: DateTime.utc(2030, 5, 21, 13, 0),
          ),
          ParsedEpgEntry(
            channelId: 'us.cnn',
            title: 'CNN Newsroom',
            startTime: DateTime.utc(2030, 5, 21, 13, 0),
            endTime: DateTime.utc(2030, 5, 21, 14, 0),
          ),
        ],
      );
    }

    test('getCurrentProgram returns airing program', () async {
      await seedEntries();

      final current = await repository.getCurrentProgram(
        'de.rtl',
        DateTime.utc(2030, 5, 21, 12, 30),
      );

      expect(current, isNotNull);
      expect(current!.title, 'RTL Aktuell');
    });

    test('getProgramsForChannel returns entries in range', () async {
      await seedEntries();

      final programs = await repository.getProgramsForChannel(
        'de.rtl',
        DateTime.utc(2030, 5, 21, 0, 0),
        DateTime.utc(2030, 5, 21, 23, 59),
      );

      expect(programs.length, 2);
      expect(
        programs.map((p) => p.title),
        containsAll(['Morning Show', 'RTL Aktuell']),
      );
    });

    test('watchEntriesInRange emits overlapping entries', () async {
      await seedEntries();

      final windowStart = DateTime.utc(2030, 5, 21, 11, 0);
      final windowEnd = DateTime.utc(2030, 5, 21, 14, 0);

      final stream = repository.watchEntriesInRange(windowStart, windowEnd);
      final first = await stream.first;

      expect(first.length, 2);
      expect(first.any((e) => e.title == 'RTL Aktuell'), isTrue);
      expect(first.any((e) => e.title == 'CNN Newsroom'), isTrue);
    });

    test('clearEntriesForChannelIds deduplicates on re-sync', () async {
      await seedEntries();

      await repository.clearEntriesForChannelIds(['de.rtl']);
      await repository.syncEpgEntries(
        entries: [
          ParsedEpgEntry(
            channelId: 'de.rtl',
            title: 'Updated Show',
            startTime: DateTime.utc(2030, 5, 22, 12, 0),
            endTime: DateTime.utc(2030, 5, 22, 13, 0),
          ),
        ],
      );

      final rtlEntries = await (db.select(
        db.epgEntries,
      )..where((tbl) => tbl.channelId.equals('de.rtl'))).get();
      final cnnEntries = await (db.select(
        db.epgEntries,
      )..where((tbl) => tbl.channelId.equals('us.cnn'))).get();

      expect(rtlEntries.length, 1);
      expect(rtlEntries.first.title, 'Updated Show');
      expect(cnnEntries.length, 1);
    });

    test('syncEpgChannels ignores duplicate display-name rows', () async {
      await repository.syncEpgChannels(
        channels: [
          const ParsedEpgChannel(channelId: 'de.rtl', displayName: 'RTL HD'),
          const ParsedEpgChannel(channelId: 'de.rtl', displayName: 'RTL HD'),
          const ParsedEpgChannel(
            channelId: 'de.rtl',
            displayName: 'RTL Television',
          ),
          const ParsedEpgChannel(channelId: 'us.cnn', displayName: 'CNN'),
        ],
      );

      final rows = await db.select(db.epgChannels).get();

      expect(rows.length, 3);
      expect(
        rows.where(
          (row) => row.channelId == 'de.rtl' && row.displayName == 'RTL HD',
        ),
        hasLength(1),
      );
      expect(
        rows.where(
          (row) =>
              row.channelId == 'de.rtl' && row.displayName == 'RTL Television',
        ),
        hasLength(1),
      );
    });

    test(
      'clearEntriesForChannelIds chunks large channel lists safely',
      () async {
        const seedChannelId = 'chunk.seed';
        await db
            .into(db.epgEntries)
            .insert(
              EpgEntriesCompanion.insert(
                channelId: seedChannelId,
                title: 'Chunk Seed',
                startTime: DateTime.utc(2030, 5, 21, 12, 0),
                endTime: DateTime.utc(2030, 5, 21, 13, 0),
              ),
            );

        final largeChannelIds = List<String>.generate(
          1001,
          (index) => 'channel-$index',
        )..add(seedChannelId);
        await repository.clearEntriesForChannelIds(largeChannelIds);

        final remaining = await db.select(db.epgEntries).get();
        expect(remaining, isEmpty);
      },
    );

    test(
      'clearChannelCatalogForChannelIds chunks large channel lists safely',
      () async {
        const seedChannelId = 'chunk.catalog.seed';
        await db
            .into(db.epgChannels)
            .insert(
              EpgChannelsCompanion.insert(
                channelId: seedChannelId,
                displayName: 'Chunk Catalog Seed',
              ),
            );

        final largeChannelIds = List<String>.generate(
          1001,
          (index) => 'catalog-$index',
        )..add(seedChannelId);
        await repository.clearChannelCatalogForChannelIds(largeChannelIds);

        final remaining = await db.select(db.epgChannels).get();
        expect(remaining, isEmpty);
      },
    );
  });
}
