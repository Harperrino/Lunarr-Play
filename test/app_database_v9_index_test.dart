import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('the catalogue query uses idx_channels_playlist_type_order', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);

    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN SELECT * FROM channels '
          'WHERE playlist_id IN (1, 2) AND channel_type = ? '
          'ORDER BY playlist_id, provider_order, name, id',
          variables: [Variable<String>('live')],
          readsFrom: {db.channels},
        )
        .get();
    final details = plan.map((row) => row.read<String>('detail')).toList();

    expect(
      details.any(
        (detail) =>
            detail.contains('idx_channels_playlist_type_order') &&
                detail.startsWith('SEARCH') ||
            detail.contains('USING COVERING INDEX'),
      ),
      isTrue,
      reason: 'full catalogue scans regressed: $details',
    );
    expect(
      details.any(
        (detail) =>
            detail == 'SCAN channels' &&
            !detail.contains('idx_channels_playlist_type_order'),
      ),
      isFalse,
      reason: 'the catalogue query must not scan the whole table: $details',
    );
  });

  test('schema v8 to v9 adds the catalogue index and survives reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'm3uxtream-v9-index-',
    );
    final file = File('${directory.path}/v9.sqlite');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    // Seed a v9 database with catalogue data, then roll it back to v8
    // without the index to simulate a pre-v9 installation.
    final created = AppDatabase.executor(NativeDatabase(file));
    final playlistId = await created
        .into(created.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Index playlist',
            type: 'm3u',
            urlOrHost: 'https://example.invalid/index.m3u',
          ),
        );
    await created
        .into(created.channels)
        .insert(
          ChannelsCompanion.insert(
            playlistId: playlistId,
            name: 'Indexed channel',
            streamUrl: 'https://example.invalid/live',
            channelType: 'live',
            providerOrder: const Value(3),
          ),
        );
    await created.close();

    final raw = sqlite3.open(file.path);
    raw.execute('DROP INDEX IF EXISTS idx_channels_playlist_type_order');
    raw.execute('PRAGMA user_version = 8');
    raw.close();

    Future<void> expectMigrated() async {
      final database = AppDatabase.executor(NativeDatabase(file));
      addTearDown(database.close);

      expect(database.schemaVersion, 10);
      final userVersion = await database
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle();
      expect(userVersion, 10);

      final indexRows = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_channels_playlist_type_order'",
          )
          .get();
      expect(indexRows, hasLength(1));

      final channel = await (database.select(
        database.channels,
      )..where((table) => table.playlistId.equals(playlistId))).getSingle();
      expect(channel.name, 'Indexed channel');
      expect(channel.providerOrder, 3);
      await database.close();
    }

    await expectMigrated();
    // Reopening an already migrated v9 database is a no-op.
    await expectMigrated();
  });
}
