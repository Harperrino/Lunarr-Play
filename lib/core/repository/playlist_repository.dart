import 'package:drift/drift.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';

typedef ChannelFavoriteIdentity = ({
  String channelType,
  String source,
  String value,
});

typedef ChannelWatchLaterIdentity = ({
  String channelType,
  String source,
  String value,
});

/// Stable sync identity for favorite preservation.
///
/// Xtream stream IDs are authoritative when present. Plain M3U channels fall
/// back to their stream URL. Names and EPG metadata are deliberately excluded
/// because providers may change them independently from the actual stream.
ChannelFavoriteIdentity channelFavoriteIdentity({
  required String channelType,
  required String? streamId,
  required String streamUrl,
}) {
  final normalizedStreamId = streamId?.trim();
  return (
    channelType: channelType.trim(),
    source: normalizedStreamId == null || normalizedStreamId.isEmpty
        ? 'url'
        : 'streamId',
    value: normalizedStreamId == null || normalizedStreamId.isEmpty
        ? streamUrl.trim()
        : normalizedStreamId,
  );
}

/// Stable sync identity for the manual Watch Later state.
///
/// This is intentionally a separate contract from live favorites so the two
/// user intents cannot accidentally share a mutation or provider boundary.
ChannelWatchLaterIdentity channelWatchLaterIdentity({
  required String channelType,
  required String? streamId,
  required String streamUrl,
}) {
  final normalizedStreamId = streamId?.trim();
  return (
    channelType: channelType.trim(),
    source: normalizedStreamId == null || normalizedStreamId.isEmpty
        ? 'url'
        : 'streamId',
    value: normalizedStreamId == null || normalizedStreamId.isEmpty
        ? streamUrl.trim()
        : normalizedStreamId,
  );
}

/// Repository responsible for handling database transactions and sync operations
/// for playlists and their associated channels inside Drift SQLite database.
class PlaylistRepository {
  final AppDatabase _db;

  PlaylistRepository(this._db);

  /// Synchronizes parsed channels for a given playlist inside the database.
  /// Wraps all operations inside a single SQLite transaction and inserts items
  /// in optimized batches of 1,000 to avoid locking the UI thread (stutter-free).
  Future<void> syncM3uChannels({
    required int playlistId,
    required List<ParsedChannel> parsedChannels,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'PlaylistRepository: Starting database sync of ${parsedChannels.length} channels for Playlist ID: $playlistId',
    );

    try {
      // Execute entire sync operation inside a single atomic SQLite transaction
      await _db.transaction(() async {
        final favoriteChannels =
            await (_db.select(_db.channels)..where(
                  (tbl) =>
                      tbl.playlistId.equals(playlistId) &
                      tbl.isFavorite.equals(true),
                ))
                .get();
        final favoriteIdentities = favoriteChannels
            .map(
              (channel) => channelFavoriteIdentity(
                channelType: channel.channelType,
                streamId: channel.streamId,
                streamUrl: channel.streamUrl,
              ),
            )
            .toSet();
        final watchLaterChannels =
            await (_db.select(_db.channels)..where(
                  (tbl) =>
                      tbl.playlistId.equals(playlistId) &
                      tbl.isWatchLater.equals(true),
                ))
                .get();
        final watchLaterIdentities = watchLaterChannels
            .map(
              (channel) => channelWatchLaterIdentity(
                channelType: channel.channelType,
                streamId: channel.streamId,
                streamUrl: channel.streamUrl,
              ),
            )
            .toSet();

        // 1. Delete all existing channel entries linked to this playlist ID
        final deleteQuery = _db.delete(_db.channels)
          ..where((tbl) => tbl.playlistId.equals(playlistId));
        final deletedCount = await deleteQuery.go();
        AppLogger.info(
          'PlaylistRepository: Deleted $deletedCount stale channels for Playlist ID: $playlistId inside transaction.',
        );

        // 2. Perform batched insert operations in chunks of 1000
        const int batchSize = 1000;
        for (int i = 0; i < parsedChannels.length; i += batchSize) {
          final chunk = parsedChannels.sublist(
            i,
            i + batchSize > parsedChannels.length
                ? parsedChannels.length
                : i + batchSize,
          );

          final companions = chunk.map((channel) {
            final identity = channelFavoriteIdentity(
              channelType: channel.channelType,
              streamId: channel.streamId,
              streamUrl: channel.streamUrl,
            );
            return ChannelsCompanion.insert(
              playlistId: playlistId,
              name: channel.name,
              logo: Value(channel.tvgLogo),
              groupName: Value(channel.groupName),
              tvgId: Value(channel.tvgId),
              streamUrl: channel.streamUrl,
              channelType: channel.channelType,
              isFavorite: Value(favoriteIdentities.contains(identity)),
              isWatchLater: Value(
                watchLaterIdentities.contains(
                  channelWatchLaterIdentity(
                    channelType: channel.channelType,
                    streamId: channel.streamId,
                    streamUrl: channel.streamUrl,
                  ),
                ),
              ),
              streamId: Value(channel.streamId),
            );
          }).toList();

          // Push companions to database within a batch context
          await _db.batch((batch) {
            batch.insertAll(_db.channels, companions);
          });
        }

        final syncedAt = DateTime.now();
        final playlistUpdateQuery = _db.update(_db.playlists)
          ..where((tbl) => tbl.id.equals(playlistId));
        await playlistUpdateQuery.write(
          PlaylistsCompanion(lastSyncedAt: Value(syncedAt)),
        );
      });

      stopwatch.stop();
      AppLogger.info(
        'PlaylistRepository: Successfully synchronized ${parsedChannels.length} channels in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'PlaylistRepository FATAL: Failed syncing channels for Playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Atomically toggles a persisted channel favorite and returns its new value.
  Future<bool> toggleChannelFavorite(int channelId) async {
    try {
      return await _db.transaction(() async {
        final channel = await (_db.select(
          _db.channels,
        )..where((tbl) => tbl.id.equals(channelId))).getSingleOrNull();
        if (channel == null) {
          throw StateError('Channel no longer exists.');
        }

        final nextValue = !channel.isFavorite;
        await (_db.update(_db.channels)
              ..where((tbl) => tbl.id.equals(channelId)))
            .write(ChannelsCompanion(isFavorite: Value(nextValue)));
        AppLogger.info(
          'PlaylistRepository: Updated favorite state for channel ID: '
          '$channelId.',
        );
        return nextValue;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed updating favorite state for channel ID: '
        '$channelId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Atomically toggles the manual Watch Later state and returns its new value.
  Future<bool> toggleChannelWatchLater(int channelId) async {
    try {
      return await _db.transaction(() async {
        final channel = await (_db.select(
          _db.channels,
        )..where((tbl) => tbl.id.equals(channelId))).getSingleOrNull();
        if (channel == null) {
          throw StateError('Channel no longer exists.');
        }

        final nextValue = !channel.isWatchLater;
        await (_db.update(_db.channels)
              ..where((tbl) => tbl.id.equals(channelId)))
            .write(ChannelsCompanion(isWatchLater: Value(nextValue)));
        AppLogger.info(
          'PlaylistRepository: Updated Watch Later state for channel ID: '
          '$channelId.',
        );
        return nextValue;
      });
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed updating Watch Later state for channel ID: '
        '$channelId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Inserts a new playlist profile inside Drift SQLite and returns the generated row ID.
  Future<int> insertPlaylist(PlaylistsCompanion playlist) async {
    try {
      final id = await _db.into(_db.playlists).insert(playlist);
      AppLogger.info(
        'PlaylistRepository: Successfully inserted new playlist. Assigned ID: $id',
      );
      return id;
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed inserting new playlist!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Updates a playlist profile in Drift SQLite.
  Future<void> updatePlaylist({
    required int playlistId,
    required PlaylistsCompanion playlist,
  }) async {
    try {
      final query = _db.update(_db.playlists)
        ..where((tbl) => tbl.id.equals(playlistId));
      await query.write(playlist);
      AppLogger.info('PlaylistRepository: Updated playlist ID: $playlistId.');
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed updating playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Retrieves all persistent playlist profiles.
  Future<List<Playlist>> getAllPlaylists() async {
    try {
      return await _db.select(_db.playlists).get();
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed fetching all playlists!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Retrieves a single playlist profile by its primary key.
  Future<Playlist?> getPlaylistById(int playlistId) async {
    try {
      return await (_db.select(
        _db.playlists,
      )..where((tbl) => tbl.id.equals(playlistId))).getSingleOrNull();
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed fetching playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Reactive stream of all playlist profiles, ordered by name.
  Stream<List<Playlist>> watchAllPlaylists() {
    return (_db.select(
      _db.playlists,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.name)])).watch();
  }

  /// Reactive stream of channels for a given playlist, ordered by name.
  /// Emits automatically when sync completes or favorites change.
  Stream<List<Channel>> watchChannelsByPlaylist(int playlistId) {
    return (_db.select(_db.channels)
          ..where((tbl) => tbl.playlistId.equals(playlistId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  /// Reactive stream scoped to a single [channelType] (`live`, `vod`, `series`).
  Stream<List<Channel>> watchChannelsByPlaylistAndType(
    int playlistId,
    String channelType,
  ) {
    return (_db.select(_db.channels)
          ..where(
            (tbl) =>
                tbl.playlistId.equals(playlistId) &
                tbl.channelType.equals(channelType),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  /// Reactive manual Watch Later stream for VOD movies and series titles.
  Stream<List<Channel>> watchWatchLaterByPlaylist(int playlistId) {
    return (_db.select(_db.channels)
          ..where(
            (tbl) =>
                tbl.playlistId.equals(playlistId) &
                (tbl.channelType.equals('vod') |
                    tbl.channelType.equals('series')) &
                tbl.isWatchLater.equals(true),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch();
  }

  /// Updates the EPG last-synced timestamp for a playlist.
  Future<void> updateEpgLastSyncedAt(int playlistId, DateTime time) async {
    try {
      final updateQuery = _db.update(_db.playlists)
        ..where((tbl) => tbl.id.equals(playlistId));
      await updateQuery.write(PlaylistsCompanion(epgLastSyncedAt: Value(time)));
      AppLogger.info(
        'PlaylistRepository: Updated epgLastSyncedAt for playlist ID: $playlistId.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed updating epgLastSyncedAt for playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Sets EPG URL from M3U header when present — never overwrites with empty values.
  Future<void> setEpgUrlFromM3uHeader(int playlistId, String? epgUrl) async {
    final trimmed = epgUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    try {
      final updateQuery = _db.update(_db.playlists)
        ..where((tbl) => tbl.id.equals(playlistId));
      await updateQuery.write(PlaylistsCompanion(epgUrl: Value(trimmed)));
      AppLogger.info(
        'PlaylistRepository: Set epgUrl from M3U header for playlist ID: $playlistId.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed setting epgUrl for playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Updates the EPG URL for an Xtream playlist (manual configuration).
  Future<void> updateEpgUrl(int playlistId, String? epgUrl) async {
    try {
      final trimmed = epgUrl?.trim();
      final updateQuery = _db.update(_db.playlists)
        ..where((tbl) => tbl.id.equals(playlistId));
      await updateQuery.write(
        PlaylistsCompanion(
          epgUrl: trimmed == null || trimmed.isEmpty
              ? const Value(null)
              : Value(trimmed),
        ),
      );
      AppLogger.info(
        'PlaylistRepository: Updated epgUrl for playlist ID: $playlistId.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed updating epgUrl for playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes a playlist by ID. Referencing channel entries are removed automatically
  /// by SQLite via cascade rules defined in Drift schema.
  Future<void> deletePlaylist(int playlistId) async {
    try {
      final count = await (_db.delete(
        _db.playlists,
      )..where((tbl) => tbl.id.equals(playlistId))).go();
      AppLogger.info(
        'PlaylistRepository: Deleted playlist ID: $playlistId (count: $count). Referenced channels cascade deleted.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlaylistRepository: Failed deleting playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
