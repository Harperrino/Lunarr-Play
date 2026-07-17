import 'dart:async';

import 'package:drift/drift.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';

/// SQLite [Variable] limit — chunk large `IN (...)` lists for grid queries.
const int epgChannelIdQueryChunkSize = 400;

/// Repository responsible for handling SQLite database synchronization
/// and lifecycle operations (caching, purging) for EPG program entries in Drift.
class EpgRepository {
  final AppDatabase _db;

  EpgRepository(this._db);

  Iterable<List<String>> _chunkChannelIds(List<String> channelIds) sync* {
    for (var i = 0; i < channelIds.length; i += epgChannelIdQueryChunkSize) {
      final endIndex = i + epgChannelIdQueryChunkSize;
      yield channelIds.sublist(
        i,
        endIndex > channelIds.length ? channelIds.length : endIndex,
      );
    }
  }

  /// Reactive stream of EPG entries overlapping the given time window.
  Stream<List<EpgEntry>> watchEntriesInRange(DateTime start, DateTime end) {
    return _watchEntriesChunk(const [], start, end, scopedToChannelIds: false);
  }

  /// Reactive stream scoped to [channelIds] within the time window (grid perf).
  Stream<List<EpgEntry>> watchEntriesInRangeForChannelIds(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) {
    final uniqueIds = channelIds.toSet().toList();
    if (uniqueIds.isEmpty) {
      return Stream.value(const []);
    }

    if (uniqueIds.length <= epgChannelIdQueryChunkSize) {
      return _watchEntriesChunk(
        uniqueIds,
        start,
        end,
        scopedToChannelIds: true,
      );
    }

    final chunks = <List<String>>[];
    for (var i = 0; i < uniqueIds.length; i += epgChannelIdQueryChunkSize) {
      final endIndex = i + epgChannelIdQueryChunkSize;
      chunks.add(
        uniqueIds.sublist(
          i,
          endIndex > uniqueIds.length ? uniqueIds.length : endIndex,
        ),
      );
    }

    return _mergeEntryStreams(chunks, start, end);
  }

  Stream<List<EpgEntry>> _watchEntriesChunk(
    List<String> channelIds,
    DateTime start,
    DateTime end, {
    required bool scopedToChannelIds,
  }) {
    return (_db.select(_db.epgEntries)
          ..where((tbl) {
            Expression<bool> predicate =
                tbl.endTime.isBiggerThanValue(start) &
                tbl.startTime.isSmallerThanValue(end);
            if (scopedToChannelIds) {
              predicate &= tbl.channelId.isIn(channelIds);
            }
            return predicate;
          })
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.channelId),
            (tbl) => OrderingTerm.asc(tbl.startTime),
          ]))
        .watch();
  }

  Stream<List<EpgEntry>> _mergeEntryStreams(
    List<List<String>> chunks,
    DateTime start,
    DateTime end,
  ) {
    return Stream.multi((controller) {
      final buffers = List<List<EpgEntry>?>.filled(chunks.length, null);
      final subscriptions = <StreamSubscription<List<EpgEntry>>>[];

      void emitMerged() {
        if (buffers.any((chunk) => chunk == null)) return;

        final merged = <EpgEntry>[];
        for (final chunk in buffers) {
          merged.addAll(chunk!);
        }
        merged.sort((a, b) {
          final byChannel = a.channelId.compareTo(b.channelId);
          if (byChannel != 0) return byChannel;
          return a.startTime.compareTo(b.startTime);
        });
        controller.add(merged);
      }

      for (var index = 0; index < chunks.length; index++) {
        final chunkIndex = index;
        subscriptions.add(
          _watchEntriesChunk(
            chunks[index],
            start,
            end,
            scopedToChannelIds: true,
          ).listen((entries) {
            buffers[chunkIndex] = entries;
            emitMerged();
          }, onError: controller.addError),
        );
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  /// All distinct XMLTV channel IDs present in cached programme data.
  Stream<Set<String>> watchDistinctProgrammeChannelIds() {
    return _db
        .customSelect(
          'SELECT DISTINCT channel_id AS channel_id FROM epg_entries',
          readsFrom: {_db.epgEntries},
        )
        .watch()
        .map(
          (rows) => rows.map((row) => row.read<String>('channel_id')).toSet(),
        );
  }

  /// XMLTV channel catalogue: channel id → display names from the last sync.
  Stream<Map<String, List<String>>> watchEpgChannelDisplayNames() {
    return (_db.select(_db.epgChannels)).watch().map((rows) {
      final map = <String, List<String>>{};
      for (final row in rows) {
        map.putIfAbsent(row.channelId, () => []).add(row.displayName);
      }
      return map;
    });
  }

  /// Combined known channel IDs (programmes + catalogue).
  Stream<Set<String>> watchKnownEpgChannelIds() {
    return _db
        .customSelect(
          '''
SELECT channel_id AS channel_id FROM epg_entries
UNION
SELECT channel_id AS channel_id FROM epg_channels
''',
          readsFrom: {_db.epgEntries, _db.epgChannels},
        )
        .watch()
        .map(
          (rows) => rows.map((row) => row.read<String>('channel_id')).toSet(),
        );
  }

  /// Returns the program currently airing on [channelId] at [now], if any.
  Future<EpgEntry?> getCurrentProgram(String channelId, DateTime now) async {
    try {
      final direct =
          await (_db.select(_db.epgEntries)
                ..where(
                  (tbl) =>
                      tbl.channelId.equals(channelId) &
                      tbl.startTime.isSmallerOrEqualValue(now) &
                      tbl.endTime.isBiggerThanValue(now),
                )
                ..limit(1))
              .getSingleOrNull();
      if (direct != null) return direct;

      return await _getCurrentProgramCaseInsensitive(channelId, now);
    } catch (e, stackTrace) {
      AppLogger.error(
        'EpgRepository: Failed fetching current program for channel "$channelId"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<EpgEntry?> _getCurrentProgramCaseInsensitive(
    String channelId,
    DateTime now,
  ) async {
    final rows = await _db
        .customSelect(
          '''
SELECT id, channel_id, title, description, start_time, end_time
FROM epg_entries
WHERE lower(channel_id) = lower(?)
  AND start_time <= ?
  AND end_time > ?
LIMIT 1
''',
          variables: [
            Variable<String>(channelId),
            Variable<DateTime>(now),
            Variable<DateTime>(now),
          ],
          readsFrom: {_db.epgEntries},
        )
        .get();

    if (rows.isEmpty) return null;
    final row = rows.first;
    return EpgEntry(
      id: row.read<int>('id'),
      channelId: row.read<String>('channel_id'),
      title: row.read<String>('title'),
      description: row.readNullable<String>('description'),
      startTime: row.read<DateTime>('start_time'),
      endTime: row.read<DateTime>('end_time'),
    );
  }

  /// Returns all programs for [channelId] that overlap [start, end].
  Future<List<EpgEntry>> getProgramsForChannel(
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final direct =
          await (_db.select(_db.epgEntries)
                ..where(
                  (tbl) =>
                      tbl.channelId.equals(channelId) &
                      tbl.endTime.isBiggerThanValue(start) &
                      tbl.startTime.isSmallerThanValue(end),
                )
                ..orderBy([(tbl) => OrderingTerm.asc(tbl.startTime)]))
              .get();
      if (direct.isNotEmpty) return direct;

      return await _getProgramsForChannelCaseInsensitive(channelId, start, end);
    } catch (e, stackTrace) {
      AppLogger.error(
        'EpgRepository: Failed fetching programs for channel "$channelId"',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<List<EpgEntry>> _getProgramsForChannelCaseInsensitive(
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _db
        .customSelect(
          '''
SELECT id, channel_id, title, description, start_time, end_time
FROM epg_entries
WHERE lower(channel_id) = lower(?)
  AND end_time > ?
  AND start_time < ?
ORDER BY start_time ASC
''',
          variables: [
            Variable<String>(channelId),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
          ],
          readsFrom: {_db.epgEntries},
        )
        .get();

    return rows
        .map(
          (row) => EpgEntry(
            id: row.read<int>('id'),
            channelId: row.read<String>('channel_id'),
            title: row.read<String>('title'),
            description: row.readNullable<String>('description'),
            startTime: row.read<DateTime>('start_time'),
            endTime: row.read<DateTime>('end_time'),
          ),
        )
        .toList();
  }

  /// Removes cached channel catalogue rows for the given channel IDs before a re-sync.
  Future<void> clearChannelCatalogForChannelIds(List<String> channelIds) async {
    if (channelIds.isEmpty) return;

    try {
      await _db.transaction(() async {
        for (final chunk in _chunkChannelIds(channelIds)) {
          await (_db.delete(
            _db.epgChannels,
          )..where((tbl) => tbl.channelId.isIn(chunk))).go();
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'EpgRepository FATAL: Failed clearing EPG channel catalogue!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Synchronizes parsed XMLTV channel display names inside Drift SQLite.
  Future<void> syncEpgChannels({
    required List<ParsedEpgChannel> channels,
  }) async {
    if (channels.isEmpty) return;

    try {
      final uniqueChannels = <String, ParsedEpgChannel>{};
      for (final channel in channels) {
        final key = '${channel.channelId}\u0000${channel.displayName}';
        uniqueChannels.putIfAbsent(key, () => channel);
      }

      final channelIds = channels.map((c) => c.channelId).toSet().toList();
      await clearChannelCatalogForChannelIds(channelIds);

      final dedupedChannels = uniqueChannels.values.toList(growable: false);
      final droppedDuplicates = channels.length - dedupedChannels.length;
      if (droppedDuplicates > 0) {
        AppLogger.info(
          'EpgRepository: Dropped $droppedDuplicates duplicate EPG channel rows before insert.',
        );
      }

      await _db.transaction(() async {
        const int batchSize = 1000;
        for (int i = 0; i < dedupedChannels.length; i += batchSize) {
          final chunk = dedupedChannels.sublist(
            i,
            i + batchSize > dedupedChannels.length
                ? dedupedChannels.length
                : i + batchSize,
          );

          final companions = chunk
              .map(
                (channel) => EpgChannelsCompanion.insert(
                  channelId: channel.channelId,
                  displayName: channel.displayName,
                ),
              )
              .toList();

          await _db.batch((batch) {
            batch.insertAll(
              _db.epgChannels,
              companions,
              mode: InsertMode.insertOrIgnore,
            );
          });
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'EpgRepository FATAL: Failed batch-inserting EPG channel catalogue!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Removes all cached entries for the given channel IDs before a re-sync.
  Future<void> clearEntriesForChannelIds(List<String> channelIds) async {
    if (channelIds.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'EpgRepository: Clearing EPG entries for ${channelIds.length} channel IDs before re-sync...',
    );

    try {
      var deletedCount = 0;
      await _db.transaction(() async {
        for (final chunk in _chunkChannelIds(channelIds)) {
          final deleteQuery = _db.delete(_db.epgEntries)
            ..where((tbl) => tbl.channelId.isIn(chunk));
          deletedCount += await deleteQuery.go();
        }
      });

      stopwatch.stop();
      AppLogger.info(
        'EpgRepository: Cleared $deletedCount EPG entries for ${channelIds.length} channels in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'EpgRepository FATAL: Failed clearing EPG entries for channel IDs!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Automatically purges expired EPG entries from SQLite.
  Future<void> purgeOutdatedEpgData() async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'EpgRepository: Initiating database purge of outdated EPG entries...',
    );

    try {
      final now = DateTime.now();
      final deleteQuery = _db.delete(_db.epgEntries)
        ..where((tbl) => tbl.endTime.isSmallerThanValue(now));
      final deletedCount = await deleteQuery.go();

      stopwatch.stop();
      AppLogger.info(
        'EpgRepository: Successfully purged $deletedCount stale EPG entries in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'EpgRepository FATAL: Failed to purge outdated EPG entries!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Synchronizes parsed EPG program entries inside Drift SQLite.
  Future<void> syncEpgEntries({required List<ParsedEpgEntry> entries}) async {
    if (entries.isEmpty) {
      AppLogger.info(
        'EpgRepository: No EPG entries to sync — skipping batch insert.',
      );
      return;
    }

    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'EpgRepository: Commencing database sync of ${entries.length} EPG entries...',
    );

    try {
      await _db.transaction(() async {
        const int batchSize = 1000;
        for (int i = 0; i < entries.length; i += batchSize) {
          final chunk = entries.sublist(
            i,
            i + batchSize > entries.length ? entries.length : i + batchSize,
          );

          final companions = chunk.map((entry) {
            return EpgEntriesCompanion.insert(
              channelId: entry.channelId,
              title: entry.title,
              description: Value(entry.description),
              startTime: entry.startTime,
              endTime: entry.endTime,
            );
          }).toList();

          await _db.batch((batch) {
            batch.insertAll(_db.epgEntries, companions);
          });
        }
      });

      stopwatch.stop();
      AppLogger.info(
        'EpgRepository: Successfully synchronized ${entries.length} EpgEntries in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'EpgRepository FATAL: Failed to batch-insert parsed EPG entries!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
