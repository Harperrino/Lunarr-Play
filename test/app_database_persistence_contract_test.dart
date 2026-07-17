import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';

void main() {
  group('AppDatabase file persistence contract', () {
    late Directory tempDirectory;
    late File databaseFile;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'm3uxtream-database-contract-',
      );
      databaseFile = File('${tempDirectory.path}/contract.sqlite');
    });

    tearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test(
      'preserves schema, data, transactions, batches and cascade deletes',
      () async {
        final createdAt = DateTime(2026, 6, 23, 10, 30);
        final startTime = DateTime(2026, 6, 23, 11);
        final endTime = DateTime(2026, 6, 23, 12);
        final database = _openFileDatabase(databaseFile);

        final playlistId = await database.transaction(() async {
          final id = await database
              .into(database.playlists)
              .insert(
                PlaylistsCompanion.insert(
                  name: 'Contract playlist',
                  type: 'm3u',
                  urlOrHost: 'https://example.invalid/list.m3u',
                  createdAt: Value(createdAt),
                ),
              );

          await database
              .into(database.appStates)
              .insert(
                AppStatesCompanion.insert(
                  key: 'contract_setting',
                  value: const Value('enabled'),
                ),
              );
          return id;
        });

        await database.batch((batch) {
          batch.insert(
            database.channels,
            ChannelsCompanion.insert(
              playlistId: playlistId,
              name: 'Contract channel',
              streamUrl: 'https://example.invalid/live/1',
              channelType: 'live',
              streamId: const Value('stream-1'),
              isFavorite: const Value(true),
              isWatchLater: const Value(true),
            ),
          );
          batch.insert(
            database.epgChannels,
            EpgChannelsCompanion.insert(
              channelId: 'contract.epg',
              displayName: 'Contract channel',
            ),
          );
          batch.insert(
            database.epgEntries,
            EpgEntriesCompanion.insert(
              channelId: 'contract.epg',
              title: 'Contract programme',
              startTime: startTime,
              endTime: endTime,
            ),
          );
        });

        await _expectSchemaContract(database);
        await database.close();

        final reopened = _openFileDatabase(databaseFile);
        addTearDown(reopened.close);

        final playlist = await reopened.select(reopened.playlists).getSingle();
        final channel = await reopened.select(reopened.channels).getSingle();
        final appState = await reopened.select(reopened.appStates).getSingle();
        final epgChannel = await reopened
            .select(reopened.epgChannels)
            .getSingle();
        final epgEntry = await reopened.select(reopened.epgEntries).getSingle();

        expect(playlist.id, playlistId);
        expect(playlist.name, 'Contract playlist');
        expect(playlist.createdAt, createdAt);
        expect(channel.playlistId, playlistId);
        expect(channel.streamId, 'stream-1');
        expect(channel.isFavorite, isTrue);
        expect(channel.isWatchLater, isTrue);
        expect(appState.value, 'enabled');
        expect(epgChannel.channelId, 'contract.epg');
        expect(epgEntry.title, 'Contract programme');
        expect(epgEntry.startTime, startTime);
        expect(epgEntry.endTime, endTime);

        await (reopened.delete(
          reopened.playlists,
        )..where((table) => table.id.equals(playlistId))).go();

        expect(await reopened.select(reopened.channels).get(), isEmpty);
        expect(await reopened.select(reopened.epgEntries).get(), hasLength(1));
        expect(await reopened.select(reopened.appStates).get(), hasLength(1));
      },
    );

    test(
      'starts a fresh v2 database without touching the legacy file',
      () async {
        final legacyFile = File(
          '${tempDirectory.path}/m3uxtream_player_db.sqlite',
        );
        const legacyBytes = <int>[0x6c, 0x65, 0x67, 0x61, 0x63, 0x79];
        await legacyFile.writeAsBytes(legacyBytes, flush: true);

        final v2File = appDatabaseFileIn(tempDirectory);
        expect(v2File.path, isNot(legacyFile.path));
        expect(v2File.uri.pathSegments.last, appDatabaseFileName);
        expect(v2File.existsSync(), isFalse);

        final database = _openFileDatabase(v2File);
        expect(await database.select(database.playlists).get(), isEmpty);
        expect(await database.select(database.appStates).get(), isEmpty);
        await database
            .into(database.appStates)
            .insert(
              AppStatesCompanion.insert(
                key: 'persisted_after_reset',
                value: const Value('yes'),
              ),
            );
        await database.close();

        final reopened = _openFileDatabase(v2File);
        final state = await reopened.select(reopened.appStates).getSingle();
        expect(state.key, 'persisted_after_reset');
        expect(state.value, 'yes');
        await reopened.close();

        expect(await legacyFile.readAsBytes(), legacyBytes);
        expect(v2File.existsSync(), isTrue);

        final logMessage = databaseConnectionLogMessage(v2File);
        expect(logMessage, contains(appDatabaseFileName));
        expect(logMessage, isNot(contains(tempDirectory.path)));
      },
    );
  });
}

AppDatabase _openFileDatabase(File file) {
  return AppDatabase.executor(NativeDatabase(file));
}

Future<void> _expectSchemaContract(AppDatabase database) async {
  expect(database.schemaVersion, 5);

  final userVersion = await database
      .customSelect('PRAGMA user_version')
      .map((row) => row.read<int>('user_version'))
      .getSingle();
  expect(userVersion, 5);

  final foreignKeys = await database
      .customSelect('PRAGMA foreign_keys')
      .map((row) => row.read<int>('foreign_keys'))
      .getSingle();
  expect(foreignKeys, 1);

  final tables = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .map((row) => row.read<String>('name'))
      .get();
  expect(tables, [
    'app_states',
    'channels',
    'epg_channels',
    'epg_entries',
    'playlists',
  ]);

  await _expectColumns(database, 'playlists', {
    'id',
    'name',
    'type',
    'url_or_host',
    'username',
    'password',
    'created_at',
    'last_synced_at',
    'epg_url',
    'epg_last_synced_at',
  });
  await _expectColumns(database, 'channels', {
    'id',
    'playlist_id',
    'stream_id',
    'name',
    'logo',
    'group_name',
    'tvg_id',
    'stream_url',
    'is_favorite',
    'is_watch_later',
    'channel_type',
    'last_watched_position',
    'duration',
    'last_watched_at',
  });
  await _expectColumns(database, 'epg_entries', {
    'id',
    'channel_id',
    'title',
    'description',
    'start_time',
    'end_time',
  });
  await _expectColumns(database, 'epg_channels', {
    'channel_id',
    'display_name',
  });
  await _expectColumns(database, 'app_states', {'key', 'value'});

  final indexSql = await database
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'index' "
        "AND name = 'idx_epg_channel_time'",
      )
      .map((row) => row.read<String>('sql'))
      .getSingle();
  expect(indexSql, contains('epg_entries (channel_id, start_time, end_time)'));

  final channelForeignKeys = await database
      .customSelect('PRAGMA foreign_key_list(channels)')
      .get();
  expect(channelForeignKeys, hasLength(1));
  expect(channelForeignKeys.single.read<String>('table'), 'playlists');
  expect(channelForeignKeys.single.read<String>('from'), 'playlist_id');
  expect(channelForeignKeys.single.read<String>('on_delete'), 'CASCADE');
}

Future<void> _expectColumns(
  AppDatabase database,
  String table,
  Set<String> expected,
) async {
  final columns = await database
      .customSelect('PRAGMA table_info($table)')
      .map((row) => row.read<String>('name'))
      .get();
  expect(columns.toSet(), expected, reason: 'Unexpected $table schema');
}
