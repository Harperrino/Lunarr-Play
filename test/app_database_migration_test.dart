import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/channel_sorting.dart';
import 'package:m3uxtream_player/core/models/playlist_epg.dart';
import 'package:sqlite3/sqlite3.dart';

const _migrationScenarios =
    <
      ({
        String name,
        bool hasProviderOrder,
        bool hasChannelNumber,
        bool userVersionSix,
      })
    >[
      (
        name: 'neither v6 column',
        hasProviderOrder: false,
        hasChannelNumber: false,
        userVersionSix: false,
      ),
      (
        name: 'provider_order only',
        hasProviderOrder: true,
        hasChannelNumber: false,
        userVersionSix: false,
      ),
      (
        name: 'channel_number only',
        hasProviderOrder: false,
        hasChannelNumber: true,
        userVersionSix: false,
      ),
      (
        name: 'both v6 columns with a v5 user version',
        hasProviderOrder: true,
        hasChannelNumber: true,
        userVersionSix: false,
      ),
      (
        name: 'already valid v6 database',
        hasProviderOrder: true,
        hasChannelNumber: true,
        userVersionSix: true,
      ),
    ];

void main() {
  group('AppDatabase v5 to v8 migration recovery', () {
    for (final scenario in _migrationScenarios) {
      test('repairs ${scenario.name} and remains idempotent', () async {
        final fixture = await _createFixture(
          hasProviderOrder: scenario.hasProviderOrder,
          hasChannelNumber: scenario.hasChannelNumber,
          userVersionSix: scenario.userVersionSix,
        );
        addTearDown(() async {
          if (await fixture.directory.exists()) {
            await fixture.directory.delete(recursive: true);
          }
        });

        await _expectRecoveredDatabase(
          fixture,
          expectedProviderOrder: scenario.hasProviderOrder ? 7 : 0,
          expectedChannelNumber: scenario.hasChannelNumber ? '42' : null,
        );

        final firstReopen = AppDatabase.executor(NativeDatabase(fixture.file));
        await firstReopen.close();

        await _expectRecoveredDatabase(
          fixture,
          expectedProviderOrder: scenario.hasProviderOrder ? 7 : 0,
          expectedChannelNumber: scenario.hasChannelNumber ? '42' : null,
        );
      });
    }

    for (final invalidColumn in const ['provider_order', 'channel_number']) {
      test(
        'rejects an incompatible $invalidColumn definition safely',
        () async {
          final fixture = await _createFixture(
            hasProviderOrder: true,
            hasChannelNumber: true,
            userVersionSix: false,
          );
          addTearDown(() async {
            if (await fixture.directory.exists()) {
              await fixture.directory.delete(recursive: true);
            }
          });

          final raw = sqlite3.open(fixture.file.path);
          raw.execute('DROP INDEX IF EXISTS idx_channels_playlist_type_order');
          raw.execute('ALTER TABLE channels DROP COLUMN $invalidColumn');
          if (invalidColumn == 'provider_order') {
            raw.execute('ALTER TABLE channels ADD COLUMN provider_order TEXT');
          } else {
            raw.execute(
              'ALTER TABLE channels ADD COLUMN channel_number '
              'INTEGER NOT NULL DEFAULT 0',
            );
          }
          raw.execute('PRAGMA user_version = 5');
          raw.close();

          final database = AppDatabase.executor(NativeDatabase(fixture.file));
          await expectLater(
            database.select(database.channels).get(),
            throwsA(
              predicate<Object>(
                (error) =>
                    error is StateError &&
                    error.toString().contains('channels.$invalidColumn') &&
                    error.toString().contains('No table rebuild or data copy'),
              ),
            ),
          );
          await database.close();

          final unchanged = sqlite3.open(fixture.file.path);
          final channelCount = unchanged
              .select('SELECT COUNT(*) AS count FROM channels')
              .single['count'];
          final userVersion = unchanged
              .select('PRAGMA user_version')
              .single['user_version'];
          unchanged.close();

          expect(channelCount, 1);
          expect(userVersion, 5);
        },
      );
    }
  });

  test(
    'schema v8 migration recreates a partially created search schema',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'm3uxtream-search-partial-',
      );
      final file = File('${directory.path}/partial.sqlite');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final created = AppDatabase.executor(NativeDatabase(file));
      final playlistId = await created
          .into(created.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Partial',
              type: 'm3u',
              urlOrHost: 'https://example.invalid/partial',
            ),
          );
      await created.close();

      final raw = sqlite3.open(file.path);
      for (final trigger in const [
        'search_documents_ai',
        'search_documents_ad',
        'search_documents_au',
        'search_documents_channel_ad',
        'search_index_state_playlist_ai',
      ]) {
        raw.execute('DROP TRIGGER IF EXISTS $trigger');
      }
      raw.execute('DROP TABLE IF EXISTS search_documents_fts_trigram');
      raw.execute('DROP TABLE IF EXISTS search_documents_fts_prefix');
      raw.execute('DROP TABLE IF EXISTS search_documents');
      raw.execute('DROP TABLE IF EXISTS search_index_state');
      raw.execute('PRAGMA user_version = 6');
      raw.close();

      final first = AppDatabase.executor(NativeDatabase(file));
      expect(first.schemaVersion, 10);
      expect(
        await first
            .customSelect(
              'SELECT COUNT(*) AS count FROM search_index_state '
              'WHERE playlist_id = ?',
              variables: [Variable<int>(playlistId)],
            )
            .map((row) => row.read<int>('count'))
            .getSingle(),
        1,
      );
      await first.close();

      final second = AppDatabase.executor(NativeDatabase(file));
      final userVersion = await second
          .customSelect('PRAGMA user_version')
          .map((row) => row.read<int>('user_version'))
          .getSingle();
      expect(userVersion, 10);
      await second.close();
    },
  );

  test(
    'schema v8 migrates legacy Xtream EPG URLs into the override column',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'm3uxtream-epg-override-',
      );
      final file = File('${directory.path}/epg.sqlite');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final created = AppDatabase.executor(NativeDatabase(file));
      final legacyXtreamId = await created
          .into(created.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Legacy Xtream',
              type: 'xtream',
              urlOrHost: 'https://example.invalid',
              epgUrl: const Value('https://example.invalid/legacy.xml'),
            ),
          );
      final automaticM3uId = await created
          .into(created.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Automatic M3U',
              type: 'm3u',
              urlOrHost: 'https://example.invalid/list.m3u',
              epgUrl: const Value('https://example.invalid/automatic.xml'),
            ),
          );
      await created.close();

      final raw = sqlite3.open(file.path);
      raw.execute('ALTER TABLE playlists DROP COLUMN epg_url_override');
      raw.execute('PRAGMA user_version = 7');
      raw.close();

      final migrated = AppDatabase.executor(NativeDatabase(file));
      final legacy = await (migrated.select(
        migrated.playlists,
      )..where((table) => table.id.equals(legacyXtreamId))).getSingle();
      final automatic = await (migrated.select(
        migrated.playlists,
      )..where((table) => table.id.equals(automaticM3uId))).getSingle();

      expect(legacy.epgUrlOverride, 'https://example.invalid/legacy.xml');
      expect(legacy.effectiveEpgUrl, 'https://example.invalid/legacy.xml');
      expect(automatic.epgUrlOverride, isNull);
      expect(
        automatic.effectiveEpgUrl,
        'https://example.invalid/automatic.xml',
      );
      await migrated.close();
    },
  );

  test(
    'schema v10 discards unowned EPG cache and resets sync timestamps',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'm3uxtream-epg-v10-',
      );
      final file = File('${directory.path}/epg-v9.sqlite');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final created = AppDatabase.executor(NativeDatabase(file));
      final playlistId = await created
          .into(created.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'EPG migration',
              type: 'm3u',
              urlOrHost: 'https://example.invalid/list.m3u',
              epgUrl: const Value('https://example.invalid/guide.xml'),
              epgLastSyncedAt: Value(DateTime.utc(2026, 7, 25)),
            ),
          );
      await created.close();

      final raw = sqlite3.open(file.path);
      raw.execute('DROP TABLE epg_entries');
      raw.execute('DROP TABLE epg_channels');
      raw.execute('''
CREATE TABLE epg_entries (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  channel_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  start_time INTEGER NOT NULL,
  end_time INTEGER NOT NULL
)''');
      raw.execute('''
CREATE TABLE epg_channels (
  channel_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  PRIMARY KEY (channel_id, display_name)
)''');
      raw.execute(
        "INSERT INTO epg_channels(channel_id, display_name) "
        "VALUES ('shared', 'Legacy')",
      );
      raw.execute(
        "INSERT INTO epg_entries(channel_id, title, start_time, end_time) "
        "VALUES ('shared', 'Legacy programme', 0, 1)",
      );
      raw.execute('PRAGMA user_version = 9');
      raw.close();

      final migrated = AppDatabase.executor(NativeDatabase(file));
      expect(await migrated.select(migrated.epgEntries).get(), isEmpty);
      expect(await migrated.select(migrated.epgChannels).get(), isEmpty);
      final playlist = await (migrated.select(
        migrated.playlists,
      )..where((table) => table.id.equals(playlistId))).getSingle();
      expect(playlist.epgLastSyncedAt, isNull);
      await migrated.close();
    },
  );
}

class _MigrationFixture {
  _MigrationFixture({
    required this.directory,
    required this.file,
    required this.playlistId,
    required this.channelId,
  });

  final Directory directory;
  final File file;
  final int playlistId;
  final int channelId;
}

Future<_MigrationFixture> _createFixture({
  required bool hasProviderOrder,
  required bool hasChannelNumber,
  required bool userVersionSix,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'm3uxtream-v6-migration-',
  );
  final file = File('${directory.path}/legacy.sqlite');
  final database = AppDatabase.executor(NativeDatabase(file));

  final playlistId = await database
      .into(database.playlists)
      .insert(
        PlaylistsCompanion.insert(
          name: 'Legacy playlist',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/legacy.m3u',
        ),
      );
  final channelId = await database
      .into(database.channels)
      .insert(
        ChannelsCompanion.insert(
          playlistId: playlistId,
          name: 'Legacy channel',
          streamUrl: 'https://example.invalid/live',
          channelType: 'live',
          streamId: const Value('legacy-stream'),
          providerOrder: const Value(7),
          channelNumber: const Value('42'),
          isFavorite: const Value(true),
        ),
      );

  final appState = AppStateRepository(database);
  await appState.setPlayerBufferSeconds(37);
  await appState.setVodPreBufferEnabled(false);
  await appState.setVodPreBufferTargetSeconds(123);
  await appState.setForceStereoEnabled(true);
  await appState.setPreferredAudioLanguage('de');
  await database.close();

  final raw = sqlite3.open(file.path);
  // The v9 catalogue index references provider_order; legacy fixtures drop
  // the column, so the index must be removed first. The migration under test
  // recreates it idempotently.
  raw.execute('DROP INDEX IF EXISTS idx_channels_playlist_type_order');
  if (!hasProviderOrder) {
    raw.execute('ALTER TABLE channels DROP COLUMN provider_order');
  }
  if (!hasChannelNumber) {
    raw.execute('ALTER TABLE channels DROP COLUMN channel_number');
  }
  if (!userVersionSix) {
    raw.execute('PRAGMA user_version = 5');
  }
  raw.close();

  return _MigrationFixture(
    directory: directory,
    file: file,
    playlistId: playlistId,
    channelId: channelId,
  );
}

Future<void> _expectRecoveredDatabase(
  _MigrationFixture fixture, {
  required int expectedProviderOrder,
  required String? expectedChannelNumber,
}) async {
  final database = AppDatabase.executor(NativeDatabase(fixture.file));
  addTearDown(database.close);

  expect(database.schemaVersion, 10);
  final userVersion = await database
      .customSelect('PRAGMA user_version')
      .map((row) => row.read<int>('user_version'))
      .getSingle();
  expect(userVersion, 10);

  final playlist = await (database.select(
    database.playlists,
  )..where((table) => table.id.equals(fixture.playlistId))).getSingle();
  final channel = await (database.select(
    database.channels,
  )..where((table) => table.id.equals(fixture.channelId))).getSingle();
  final appStates = await database.select(database.appStates).get();

  expect(playlist.name, 'Legacy playlist');
  expect(playlist.urlOrHost, 'https://example.invalid/legacy.m3u');
  expect(playlist.lastSyncedAt, isNull);
  expect(channel.name, 'Legacy channel');
  expect(channel.streamUrl, 'https://example.invalid/live');
  expect(channel.isFavorite, isTrue);
  expect(channel.providerOrder, expectedProviderOrder);
  expect(
    effectiveChannelProviderOrder(channel),
    expectedProviderOrder == 0 ? channel.id : expectedProviderOrder,
  );
  expect(channel.channelNumber, expectedChannelNumber);
  expect(
    Map<String, String?>.fromEntries(
      appStates.map((state) => MapEntry(state.key, state.value)),
    ),
    {
      AppStateRepository.playerBufferSecondsKey: '37',
      AppStateRepository.vodPreBufferEnabledKey: 'false',
      AppStateRepository.vodPreBufferTargetSecondsKey: '123',
      AppStateRepository.forceStereoEnabledKey: 'true',
      AppStateRepository.preferredAudioLanguageKey: 'de',
    },
  );

  final columns = await database
      .customSelect('PRAGMA table_info("channels")')
      .map(
        (row) => MapEntry(row.read<String>('name'), <String, Object?>{
          'type': row.read<String>('type'),
          'notnull': row.read<int>('notnull'),
          'dflt_value': row.readNullable<String>('dflt_value'),
        }),
      )
      .get();
  final definitions = Map<String, Map<String, Object?>>.fromEntries(columns);
  expect(definitions['provider_order'], {
    'type': 'INTEGER',
    'notnull': 1,
    'dflt_value': '0',
  });
  expect(definitions['channel_number'], {
    'type': 'TEXT',
    'notnull': 0,
    'dflt_value': null,
  });

  final searchState = await database
      .customSelect(
        'SELECT status, document_count FROM search_index_state '
        'WHERE playlist_id = ?',
        variables: [Variable<int>(fixture.playlistId)],
      )
      .getSingle();
  expect(searchState.read<String>('status'), 'pending');
  expect(searchState.read<int>('document_count'), 0);
  expect(
    await database
        .customSelect(
          'SELECT COUNT(*) AS count FROM search_documents '
          'WHERE playlist_id = ?',
          variables: [Variable<int>(fixture.playlistId)],
        )
        .map((row) => row.read<int>('count'))
        .getSingle(),
    0,
  );

  final playlistRepository = PlaylistRepository(database);
  expect(
    (await playlistRepository.watchAllPlaylists().first).map((row) => row.id),
    [fixture.playlistId],
  );
  expect(
    (await playlistRepository.watchChannelsByPlaylist(fixture.playlistId).first)
        .single
        .isFavorite,
    isTrue,
  );

  final appStateRepository = AppStateRepository(database);
  expect(await appStateRepository.getForceStereoEnabled(), isTrue);
  expect(await appStateRepository.getPreferredAudioLanguage(), 'de');
  expect(await appStateRepository.getPlayerBufferSeconds(), 37);
  expect(await appStateRepository.getVodPreBufferEnabled(), isFalse);
  expect(await appStateRepository.getVodPreBufferTargetSeconds(), 123);

  await database.close();
}
