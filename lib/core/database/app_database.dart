import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:m3uxtream_player/core/logger/app_logger.dart';

part 'app_database.g.dart';

const appDatabaseFileName = 'm3uxtream_player_db_v2.sqlite';

File appDatabaseFileIn(Directory directory) {
  return File(p.join(directory.path, appDatabaseFileName));
}

String databaseConnectionLogMessage(File file) {
  return 'Database Connection: Initializing native SQLite connection '
      'for file "${p.basename(file.path)}".';
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
  AppDatabase() : super(_openConnection());
  AppDatabase.executor(super.e);

  Future<void>? _closeFuture;

  @override
  int get schemaVersion => 5;

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
          AppLogger.info(
            'Database Migration: onCreate successfully completed with Indexes.',
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
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = appDatabaseFileIn(dbFolder);

      AppLogger.info(databaseConnectionLogMessage(file));

      // NativeDatabase.createInBackground handles disk writes off the main UI thread to prevent visual stuttering (120Hz).
      return NativeDatabase.createInBackground(file);
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
