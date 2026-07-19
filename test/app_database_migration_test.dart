import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates a v5 channel table and backfills provider order', () async {
    final directory = await Directory.systemTemp.createTemp(
      'm3uxtream-v6-migration-',
    );
    final file = File('${directory.path}/legacy.sqlite');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final seeded = AppDatabase.executor(NativeDatabase(file));
    final playlistId = await seeded
        .into(seeded.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Legacy playlist',
            type: 'm3u',
            urlOrHost: 'https://example.invalid/legacy.m3u',
          ),
        );
    await seeded
        .into(seeded.channels)
        .insert(
          ChannelsCompanion.insert(
            playlistId: playlistId,
            name: 'Legacy channel',
            streamUrl: 'https://example.invalid/live',
            channelType: 'live',
          ),
        );
    await seeded.close();

    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE channels DROP COLUMN provider_order');
    raw.execute('ALTER TABLE channels DROP COLUMN channel_number');
    raw.execute('PRAGMA user_version = 5');
    raw.close();

    final migrated = AppDatabase.executor(NativeDatabase(file));
    addTearDown(migrated.close);

    expect(migrated.schemaVersion, 6);
    final channel = await migrated.select(migrated.channels).getSingle();
    expect(channel.providerOrder, channel.id);
    expect(channel.channelNumber, isNull);

    final userVersion = await migrated
        .customSelect('PRAGMA user_version')
        .map((row) => row.read<int>('user_version'))
        .getSingle();
    expect(userVersion, 6);
  });
}
