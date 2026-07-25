import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:m3uxtream_player/core/database/database_health_interceptor.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/search/search_schema.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';

part 'app_database.g.dart';

const appDatabaseFileName = 'm3uxtream_player_db_v2.sqlite';

File appDatabaseFileIn(Directory directory) {
  return File(p.join(directory.path, appDatabaseFileName));
}

String databaseConnectionLogMessage(File file) {
  return 'Database Connection: Initializing native SQLite connection '
      'for file "${p.basename(file.path)}".';
}

typedef _SqliteColumnDefinition = ({
  String type,
  bool notNull,
  String? defaultValue,
});

Future<Map<String, _SqliteColumnDefinition>> _readChannelsColumnDefinitions(
  GeneratedDatabase database,
) async {
  final rows = await database
      .customSelect('PRAGMA table_info("channels")')
      .get();

  return {
    for (final row in rows)
      row.read<String>('name'): (
        type: row.read<String>('type').trim().toUpperCase(),
        notNull: row.read<int>('notnull') != 0,
        defaultValue: row
            .readNullable<String>('dflt_value')
            ?.trim()
            .toUpperCase(),
      ),
  };
}

/// Idempotent composite catalogue index. Playlist catalogues filter by
/// (playlist_id, channel_type) and sort by provider_order; without it SQLite
/// scans the whole channels table on every catalogue switch.
Future<void> _ensureChannelCatalogIndex(Migrator m) async {
  await m.createIndex(
    Index(
      'channels',
      'CREATE INDEX IF NOT EXISTS idx_channels_playlist_type_order '
      'ON channels (playlist_id, channel_type, provider_order);',
    ),
  );
}

void _validateExistingChannelColumn(
  Map<String, _SqliteColumnDefinition> columns, {
  required String name,
  required String expectedType,
  required bool expectedNotNull,
  required String? expectedDefault,
  required String expectedDescription,
}) {
  final existing = columns[name];
  if (existing == null) return;

  if (existing.type != expectedType ||
      existing.notNull != expectedNotNull ||
      existing.defaultValue != expectedDefault) {
    throw StateError(
      'Database Migration: Refusing to repair incompatible channels.$name '
      'definition; expected $expectedDescription. No table rebuild or data '
      'copy was attempted.',
    );
  }
}

// ==========================================
// 1. PLAYLISTS TABLE
// ==========================================
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get type => text()(); // 'm3u' or 'xtream'
  TextColumn get urlOrHost => text()();
  TextColumn get username => text().nullable()();
  TextColumn get password => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get epgUrl => text().nullable()();
  TextColumn get epgUrlOverride => text().nullable()();
  DateTimeColumn get epgLastSyncedAt => dateTime().nullable()();
}

// ==========================================
// 2. CHANNELS TABLE (Live, VOD, Series)
// ==========================================
class Channels extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  // Xtream Codes API stream_id or index
  TextColumn get streamId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get logo => text().nullable()();
  TextColumn get groupName => text().nullable()(); // tvg-group or Category Name
  TextColumn get tvgId => text().nullable()(); // EPG Mapping-ID from XMLTV
  TextColumn get streamUrl => text()();
  IntColumn get providerOrder => integer().withDefault(const Constant(0))();
  TextColumn get channelNumber => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isWatchLater => boolean().withDefault(const Constant(false))();

  // Distinguish channel types: 'live', 'vod', 'series'
  TextColumn get channelType => text()();

  // Playback state caching (VOD/Series Auto-Resume)
  IntColumn get lastWatchedPosition =>
      integer().nullable()(); // Position in Milliseconds
  IntColumn get duration =>
      integer().nullable()(); // Total duration in Milliseconds
  DateTimeColumn get lastWatchedAt => dateTime().nullable()();
}

// ==========================================
// 3. EPG DATA TABLE (XMLTV Program Cache)
// ==========================================
class EpgEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get channelId =>
      text()(); // Matches tvgId in Channels or channel-id in XMLTV
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
}

// ==========================================
// 3b. EPG CHANNEL CATALOG (XMLTV display-name → channel id)
// ==========================================
class EpgChannels extends Table {
  TextColumn get channelId => text()();
  TextColumn get displayName => text()();

  @override
  Set<Column<Object>> get primaryKey => {channelId, displayName};
}

// ==========================================
// 4. APP STATE TABLE (Persistent Settings Cache)
// ==========================================
class AppStates extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

// ==========================================
// DRIFT DATABASE IMPLEMENTATION
// ==========================================
@DriftDatabase(
  tables: [Playlists, Channels, EpgEntries, EpgChannels, AppStates],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({DatabaseHealthController? health})
    : super(_openConnection(health));

  AppDatabase.executor(
    QueryExecutor executor, {
    DatabaseHealthController? health,
  }) : super(
         health == null
             ? executor
             : executor.interceptWith(DatabaseHealthInterceptor(health)),
       );

  Future<void>? _closeFuture;

  @override
  int get schemaVersion => 9;

  @override
  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;

    final future = super.close();
    _closeFuture = future;
    return future;
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        AppLogger.info('Database Migration: onCreate started.');
        try {
          // Construct all defined tables inside the database context
          await m.createAll();

          // Performance Tuning: Custom SQLite index for EPG-channel queries
          await m.createIndex(
            Index(
              'epg_entries',
              'CREATE INDEX IF NOT EXISTS idx_epg_channel_time ON epg_entries (channel_id, start_time, end_time);',
            ),
          );
          await _ensureChannelCatalogIndex(m);
          await ensureSearchSchema(m.database);
          AppLogger.info(
            'Database Migration: onCreate successfully completed with Indexes and Search schema.',
          );
        } catch (e, stackTrace) {
          AppLogger.error(
            'Database Migration FATAL: Failed creating database schema inside onCreate!',
            e,
            stackTrace,
          );
          rethrow;
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        AppLogger.info(
          'Database Migration: onUpgrade started from version $from to $to.',
        );
        try {
          if (from < 2) {
            await m.addColumn(playlists, playlists.epgUrl);
            await m.addColumn(playlists, playlists.epgLastSyncedAt);
            AppLogger.info(
              'Database Migration: Added Playlists.epgUrl and Playlists.epgLastSyncedAt (v1 → v2).',
            );
          }
          if (from < 3) {
            await m.createTable(epgChannels);
            AppLogger.info(
              'Database Migration: Created EpgChannels table (v2 → v3).',
            );
          }
          if (from < 4) {
            await m.createIndex(
              Index(
                'epg_entries',
                'CREATE INDEX IF NOT EXISTS idx_epg_channel_time ON epg_entries (channel_id, start_time, end_time);',
              ),
            );
            AppLogger.info(
              'Database Migration: Ensured idx_epg_channel_time (v3 → v4).',
            );
          }
          if (from < 5) {
            await m.addColumn(channels, channels.isWatchLater);
            AppLogger.info(
              'Database Migration: Added Channels.isWatchLater (v4 → v5).',
            );
          }
          if (from < 6) {
            final channelColumns = await _readChannelsColumnDefinitions(
              m.database,
            );
            _validateExistingChannelColumn(
              channelColumns,
              name: 'provider_order',
              expectedType: 'INTEGER',
              expectedNotNull: true,
              expectedDefault: '0',
              expectedDescription: 'INTEGER NOT NULL DEFAULT 0',
            );
            _validateExistingChannelColumn(
              channelColumns,
              name: 'channel_number',
              expectedType: 'TEXT',
              expectedNotNull: false,
              expectedDefault: null,
              expectedDescription: 'nullable TEXT',
            );

            final hasProviderOrder = channelColumns.containsKey(
              'provider_order',
            );
            final hasChannelNumber = channelColumns.containsKey(
              'channel_number',
            );
            if (hasProviderOrder || hasChannelNumber) {
              AppLogger.info(
                'Database Migration: Detected compatible partial channel '
                'ordering metadata; only missing v6 columns will be added.',
              );
            }

            if (!hasProviderOrder) {
              await m.addColumn(channels, channels.providerOrder);
            }
            if (!hasChannelNumber) {
              await m.addColumn(channels, channels.channelNumber);
            }
            AppLogger.info(
              'Database Migration: Ensured channel ordering metadata (v5 → v6); '
              'provider order 0 uses the channel ID at runtime.',
            );
          }
          if (from < 7) {
            await ensureSearchSchema(m.database);
            AppLogger.info(
              'Database Migration: Ensured persistent SQLite search schema (v6 → v7).',
            );
          }
          if (from < 8) {
            final playlistColumns = await m.database
                .customSelect('PRAGMA table_info("playlists")')
                .get();
            final hasEpgOverride = playlistColumns.any(
              (row) => row.read<String>('name') == 'epg_url_override',
            );
            if (!hasEpgOverride) {
              await m.addColumn(playlists, playlists.epgUrlOverride);
            }

            // Older Xtream forms stored their manually entered URL in the
            // automatic epg_url column. Move that data exactly once; M3U
            // header metadata remains automatic and must not become an
            // override.
            await m.database.customStatement(
              'UPDATE playlists '
              'SET epg_url_override = epg_url '
              'WHERE type = \'xtream\' '
              'AND epg_url_override IS NULL '
              'AND epg_url IS NOT NULL '
              'AND trim(epg_url) <> \'\'',
            );
            AppLogger.info(
              'Database Migration: Ensured playlist EPG override column and migrated legacy Xtream URLs (v7 → v8).',
            );
          }
          if (from < 9) {
            await _ensureChannelCatalogIndex(m);
            AppLogger.info(
              'Database Migration: Ensured idx_channels_playlist_type_order (v8 → v9).',
            );
          }
          AppLogger.info(
            'Database Migration: onUpgrade completed successfully.',
          );
        } catch (e, stackTrace) {
          AppLogger.error(
            'Database Migration FATAL: Upgrade failed from version $from to $to!',
            e,
            stackTrace,
          );
          rethrow;
        }
      },
      beforeOpen: (details) async {
        AppLogger.debug(
          'Database Lifecycle: beforeOpen invoked. Version: ${details.versionNow} (Previously: ${details.versionBefore}).',
        );
        try {
          // Zwingend erforderlich: Enable SQLite foreign key constraints
          await customStatement('PRAGMA foreign_keys = ON;');
          AppLogger.debug(
            'Database Lifecycle: SQLite Foreign Keys are successfully enabled (PRAGMA foreign_keys = ON).',
          );
        } catch (e, stackTrace) {
          AppLogger.error(
            'Database Lifecycle WARNING: Could not set foreign_keys constraint status!',
            e,
            stackTrace,
          );
        }
      },
    );
  }
}

/// Helper function to open the platform-specific database connection file.
LazyDatabase _openConnection(DatabaseHealthController? health) {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = appDatabaseFileIn(dbFolder);

      AppLogger.info(databaseConnectionLogMessage(file));

      // NativeDatabase.createInBackground handles disk writes off the main UI thread to prevent visual stuttering (120Hz).
      final executor = NativeDatabase.createInBackground(file);
      return health == null
          ? executor
          : executor.interceptWith(DatabaseHealthInterceptor(health));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Database Connection FATAL: Failed to resolve SQLite database directory path!',
        e,
        stackTrace,
      );
      rethrow;
    }
  });
}
