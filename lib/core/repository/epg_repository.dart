import 'dart:async';

import 'package:drift/drift.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';

/// SQLite [Variable] limit — chunk large `IN (...)` lists for grid queries.
const int epgChannelIdQueryChunkSize = 400;

/// Repository responsible for handling SQLite database synchronization
/// and lifecycle operations (caching, purging) for EPG program entries in Drift.
class EpgRepository {
  final AppDatabase _db;
  final AppLifecycleGate? lifecycleGate;

  EpgRepository(this._db, {this.lifecycleGate});

  Iterable<List<String>> _chunkChannelIds(List<String> channelIds) sync* {
    for (var i = 0; i < channelIds.length; i += epgChannelIdQueryChunkSize) {
      final endIndex = i + epgChannelIdQueryChunkSize;
      yield channelIds.sublist(
        i,
        endIndex > channelIds.length ? channelIds.length : endIndex,
      );
    }
  }

  /// Reactive stream of EPG entries for the requested playlists and window.
  Stream<List<EpgEntry>> watchEntriesInRangeForPlaylistIds(
    Set<int> playlistIds,
    DateTime start,
    DateTime end,
  ) {
    if (playlistIds.isEmpty) return Stream.value(const []);
    return (_db.select(_db.epgEntries)
          ..where(
            (tbl) =>
                tbl.playlistId.isIn(playlistIds) &
                tbl.endTime.isBiggerThanValue(start) &
                tbl.startTime.isSmallerThanValue(end),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.playlistId),
            (tbl) => OrderingTerm.asc(tbl.channelId),
            (tbl) => OrderingTerm.asc(tbl.startTime),
          ]))
        .watch();
  }

  /// Reactive stream scoped to playlist-owned XMLTV channel IDs.
  Stream<List<EpgEntry>> watchEntriesInRangeForPlaylistChannelIds(
    Map<int, Set<String>> channelIdsByPlaylist,
    DateTime start,
    DateTime end,
  ) {
    final chunks = <({int playlistId, List<String> channelIds})>[];
    for (final entry in channelIdsByPlaylist.entries) {
      final uniqueIds = entry.value.toList(growable: false);
      for (final chunk in _chunkChannelIds(uniqueIds)) {
        chunks.add((playlistId: entry.key, channelIds: chunk));
      }
    }
    if (chunks.isEmpty) return Stream.value(const []);
    if (chunks.length == 1) {
      final chunk = chunks.single;
      return _watchEntriesChunk(chunk.playlistId, chunk.channelIds, start, end);
    }
    return _mergeEntryStreams(chunks, start, end);
  }

  /// One non-reactive EPG snapshot for a grid scope/window.
  ///
  /// SQLite-limit chunks are read in deterministic playlist/channel order and
  /// appended once. There are no chunk watchers and no repeated whole-result
  /// sort; callers publish the completed snapshot as one logical value.
  Future<List<EpgEntry>> getEntriesSnapshotForPlaylistChannelIds(
    Map<int, Set<String>> channelIdsByPlaylist,
    DateTime start,
    DateTime end,
  ) async {
    if (channelIdsByPlaylist.isEmpty) return const [];

    final playlistIds = channelIdsByPlaylist.keys.toList()..sort();
    final merged = <EpgEntry>[];
    for (final playlistId in playlistIds) {
      final channelIds =
          channelIdsByPlaylist[playlistId]?.toList(growable: false) ??
          const <String>[];
      channelIds.sort();
      for (final chunk in _chunkChannelIds(channelIds)) {
        merged.addAll(await _getEntriesChunk(playlistId, chunk, start, end));
      }
    }
    return List<EpgEntry>.unmodifiable(merged);
  }

  Future<List<EpgEntry>> _getEntriesChunk(
    int playlistId,
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) {
    return (_db.select(_db.epgEntries)
          ..where(
            (tbl) =>
                tbl.playlistId.equals(playlistId) &
                tbl.endTime.isBiggerThanValue(start) &
                tbl.startTime.isSmallerThanValue(end) &
                tbl.channelId.isIn(channelIds),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.channelId),
            (tbl) => OrderingTerm.asc(tbl.startTime),
          ]))
        .get();
  }

  Stream<List<EpgEntry>> _watchEntriesChunk(
    int playlistId,
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) {
    return (_db.select(_db.epgEntries)
          ..where(
            (tbl) =>
                tbl.playlistId.equals(playlistId) &
                tbl.endTime.isBiggerThanValue(start) &
                tbl.startTime.isSmallerThanValue(end) &
                tbl.channelId.isIn(channelIds),
          )
          ..orderBy([
            (tbl) => OrderingTerm.asc(tbl.channelId),
            (tbl) => OrderingTerm.asc(tbl.startTime),
          ]))
        .watch();
  }

  Stream<List<EpgEntry>> _mergeEntryStreams(
    List<({int playlistId, List<String> channelIds})> chunks,
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
          final byPlaylist = a.playlistId.compareTo(b.playlistId);
          if (byPlaylist != 0) return byPlaylist;
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
            chunks[index].playlistId,
            chunks[index].channelIds,
            start,
            end,
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

  /// All distinct XMLTV channel IDs grouped by owning playlist.
  Stream<Map<int, Set<String>>> watchDistinctProgrammeChannelIds() {
    return _db
        .customSelect(
          'SELECT DISTINCT playlist_id, channel_id FROM epg_entries',
          readsFrom: {_db.epgEntries},
        )
        .watch()
        .map((rows) {
          final result = <int, Set<String>>{};
          for (final row in rows) {
            result
                .putIfAbsent(row.read<int>('playlist_id'), () => <String>{})
                .add(row.read<String>('channel_id'));
          }
          return result;
        });
  }

  /// XMLTV channel catalogue grouped by playlist and channel ID.
  Stream<Map<int, Map<String, List<String>>>> watchEpgChannelDisplayNames() {
    return (_db.select(_db.epgChannels)).watch().map((rows) {
      final map = <int, Map<String, List<String>>>{};
      for (final row in rows) {
        map
            .putIfAbsent(row.playlistId, () => <String, List<String>>{})
            .putIfAbsent(row.channelId, () => <String>[])
            .add(row.displayName);
      }
      return map;
    });
  }

  /// Combined known channel IDs grouped by owning playlist.
  Stream<Map<int, Set<String>>> watchKnownEpgChannelIds() {
    return _db
        .customSelect(
          '''
SELECT playlist_id, channel_id FROM epg_entries
UNION
SELECT playlist_id, channel_id FROM epg_channels
''',
          readsFrom: {_db.epgEntries, _db.epgChannels},
        )
        .watch()
        .map((rows) {
          final result = <int, Set<String>>{};
          for (final row in rows) {
            result
                .putIfAbsent(row.read<int>('playlist_id'), () => <String>{})
                .add(row.read<String>('channel_id'));
          }
          return result;
        });
  }

  /// Returns the program currently airing on [channelId] at [now], if any.
  Future<EpgEntry?> getCurrentProgram(
    int playlistId,
    String channelId,
    DateTime now,
  ) async {
    try {
      final direct =
          await (_db.select(_db.epgEntries)
                ..where(
                  (tbl) =>
                      tbl.playlistId.equals(playlistId) &
                      tbl.channelId.equals(channelId) &
                      tbl.startTime.isSmallerOrEqualValue(now) &
                      tbl.endTime.isBiggerThanValue(now),
                )
                ..limit(1))
              .getSingleOrNull();
      if (direct != null) return direct;

      return await _getCurrentProgramCaseInsensitive(
        playlistId,
        channelId,
        now,
      );
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
    int playlistId,
    String channelId,
    DateTime now,
  ) async {
    final rows = await _db
        .customSelect(
          '''
SELECT id, playlist_id, channel_id, title, description, start_time, end_time
FROM epg_entries
WHERE playlist_id = ?
  AND lower(channel_id) = lower(?)
  AND start_time <= ?
  AND end_time > ?
LIMIT 1
''',
          variables: [
            Variable<int>(playlistId),
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
      playlistId: row.read<int>('playlist_id'),
      channelId: row.read<String>('channel_id'),
      title: row.read<String>('title'),
      description: row.readNullable<String>('description'),
      startTime: row.read<DateTime>('start_time'),
      endTime: row.read<DateTime>('end_time'),
    );
  }

  /// Returns all programs for [channelId] that overlap [start, end].
  Future<List<EpgEntry>> getProgramsForChannel(
    int playlistId,
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final direct =
          await (_db.select(_db.epgEntries)
                ..where(
                  (tbl) =>
                      tbl.playlistId.equals(playlistId) &
                      tbl.channelId.equals(channelId) &
                      tbl.endTime.isBiggerThanValue(start) &
                      tbl.startTime.isSmallerThanValue(end),
                )
                ..orderBy([(tbl) => OrderingTerm.asc(tbl.startTime)]))
              .get();
      if (direct.isNotEmpty) return direct;

      return await _getProgramsForChannelCaseInsensitive(
        playlistId,
        channelId,
        start,
        end,
      );
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
    int playlistId,
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _db
        .customSelect(
          '''
SELECT id, playlist_id, channel_id, title, description, start_time, end_time
FROM epg_entries
WHERE playlist_id = ?
  AND lower(channel_id) = lower(?)
  AND end_time > ?
  AND start_time < ?
ORDER BY start_time ASC
''',
          variables: [
            Variable<int>(playlistId),
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
            playlistId: row.read<int>('playlist_id'),
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
  Future<void> clearChannelCatalogForChannelIds(
    int playlistId,
    List<String> channelIds,
  ) async {
    if (channelIds.isEmpty) return;
    _ensureWritable();

    try {
      await _db.transaction(() async {
        for (final chunk in _chunkChannelIds(channelIds)) {
          await (_db.delete(_db.epgChannels)..where(
                (tbl) =>
                    tbl.playlistId.equals(playlistId) &
                    tbl.channelId.isIn(chunk),
              ))
              .go();
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
    required int playlistId,
    required List<ParsedEpgChannel> channels,
  }) async {
    if (channels.isEmpty) return;
    _ensureWritable();

    try {
      final uniqueChannels = <String, ParsedEpgChannel>{};
      for (final channel in channels) {
        final key = '${channel.channelId}\u0000${channel.displayName}';
        uniqueChannels.putIfAbsent(key, () => channel);
      }

      final channelIds = channels.map((c) => c.channelId).toSet().toList();
      await clearChannelCatalogForChannelIds(playlistId, channelIds);

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
                  playlistId: playlistId,
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
  Future<void> clearEntriesForChannelIds(
    int playlistId,
    List<String> channelIds,
  ) async {
    if (channelIds.isEmpty) return;
    _ensureWritable();

    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'EpgRepository: Clearing EPG entries for ${channelIds.length} channel IDs before re-sync...',
    );

    try {
      var deletedCount = 0;
      await _db.transaction(() async {
        for (final chunk in _chunkChannelIds(channelIds)) {
          final deleteQuery = _db.delete(_db.epgEntries)
            ..where(
              (tbl) =>
                  tbl.playlistId.equals(playlistId) & tbl.channelId.isIn(chunk),
            );
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
    _ensureWritable();
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
  Future<void> syncEpgEntries({
    required int playlistId,
    required List<ParsedEpgEntry> entries,
  }) async {
    if (entries.isEmpty) {
      AppLogger.info(
        'EpgRepository: No EPG entries to sync — skipping batch insert.',
      );
      return;
    }
    _ensureWritable();

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
              playlistId: playlistId,
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

  /// Atomically replaces the imported programme and channel-catalogue rows.
  ///
  /// Limit/cancellation checks happen before and throughout the transaction;
  /// any failure rolls back both tables together.
  Future<void> replaceImportedEpgData({
    required int playlistId,
    required List<ParsedEpgEntry> entries,
    required List<ParsedEpgChannel> channels,
    required ImportBudget budget,
    bool rowsCounted = false,
  }) async {
    _ensureWritable();

    final uniqueChannels = <String, ParsedEpgChannel>{};
    for (final channel in channels) {
      final key = '${channel.channelId}\u0000${channel.displayName}';
      uniqueChannels.putIfAbsent(key, () => channel);
    }
    final dedupedChannels = uniqueChannels.values.toList(growable: false);
    if (!rowsCounted) {
      budget.acceptPersistedRows(
        entries.length + dedupedChannels.length,
        phase: 'xmltv_persist',
      );
    }
    budget.checkpoint('xmltv_persist');

    final entryChannelIds = entries.map((entry) => entry.channelId).toSet();
    final catalogueChannelIds = channels
        .map((channel) => channel.channelId)
        .toSet();

    await _db.transaction(() async {
      for (final chunk in _chunkChannelIds(entryChannelIds.toList())) {
        budget.checkpoint('xmltv_persist');
        await (_db.delete(_db.epgEntries)..where(
              (table) =>
                  table.playlistId.equals(playlistId) &
                  table.channelId.isIn(chunk),
            ))
            .go();
      }
      for (final chunk in _chunkChannelIds(catalogueChannelIds.toList())) {
        budget.checkpoint('xmltv_persist');
        await (_db.delete(_db.epgChannels)..where(
              (table) =>
                  table.playlistId.equals(playlistId) &
                  table.channelId.isIn(chunk),
            ))
            .go();
      }

      const batchSize = 1000;
      for (var index = 0; index < entries.length; index += batchSize) {
        budget.checkpoint('xmltv_persist');
        final end = index + batchSize > entries.length
            ? entries.length
            : index + batchSize;
        final companions = entries
            .sublist(index, end)
            .map(
              (entry) => EpgEntriesCompanion.insert(
                playlistId: playlistId,
                channelId: entry.channelId,
                title: entry.title,
                description: Value(entry.description),
                startTime: entry.startTime,
                endTime: entry.endTime,
              ),
            )
            .toList();
        await _db.batch((batch) {
          batch.insertAll(_db.epgEntries, companions);
        });
      }

      for (var index = 0; index < dedupedChannels.length; index += batchSize) {
        budget.checkpoint('xmltv_persist');
        final end = index + batchSize > dedupedChannels.length
            ? dedupedChannels.length
            : index + batchSize;
        final companions = dedupedChannels
            .sublist(index, end)
            .map(
              (channel) => EpgChannelsCompanion.insert(
                playlistId: playlistId,
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
  }

  void _ensureWritable() {
    lifecycleGate?.ensureWritable();
  }
}
