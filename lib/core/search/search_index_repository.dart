import 'dart:async';

import 'package:drift/drift.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';

import 'search_models.dart';
import 'search_normalization.dart';
import 'search_schema.dart';

class SearchIndexRepository {
  SearchIndexRepository(this._db, {this.lifecycleGate});

  static const _batchSize = 1000;
  static const _searchDocumentType = 'channel';

  final AppDatabase _db;
  final AppLifecycleGate? lifecycleGate;
  final StreamController<void> _stateChanges =
      StreamController<void>.broadcast();
  Future<void>? _ensureFuture;
  Future<void>? _retryFuture;
  bool _disposed = false;
  bool _shutdownStarted = false;

  void beginShutdown() {
    _shutdownStarted = true;
    lifecycleGate?.beginShutdown();
  }

  Future<void> drain() async {
    final futures = <Future<void>>[?_ensureFuture, ?_retryFuture];
    for (final future in futures) {
      try {
        await future;
      } catch (_) {
        // A cancelled/failed background build must not block the database
        // close. Its per-playlist state remains available for a later retry.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await drain();
    _disposed = true;
    await _stateChanges.close();
  }

  Future<List<SearchHit>> search(SearchRequest request) {
    // An active search is a registered lifecycle job: shutdown drains it
    // before the SQLite connection may close.
    return _runTracked(() => _search(request));
  }

  Future<List<SearchHit>> _search(SearchRequest request) async {
    final query = normalizeSearchText(request.query);
    if (query.isEmpty || request.activePlaylistIds.isEmpty) return const [];

    final rows = await _readSearchRows(
      request,
      query,
      fetchLimit: _fetchLimit(request.limit),
    );
    if (rows.isEmpty) return const [];

    final hidden = _normalizeGroups(request.hiddenGroupsByPlaylist);
    final pinned = _normalizeGroups(request.pinnedGroupsByPlaylist);
    final channels = <SearchHit>[];
    final categories = <SearchHit>[];
    final seenCategories = <String>{};
    final seenDocuments = <int>{};

    for (final row in rows) {
      if (!seenDocuments.add(row.documentId)) continue;
      final normalizedCategory = normalizeSearchCategory(row.category);
      if (_isHidden(hidden, row.playlistId, normalizedCategory)) continue;

      if (request.tab != SearchResultTab.categories &&
          row.mediaType == 'live') {
        final relevance = _matchRelevance(row.normalizedTitle, query);
        if (relevance != null && row.channelId != null) {
          channels.add(
            SearchHit(
              type: SearchHitType.channel,
              playlistId: row.playlistId,
              playlistName: row.playlistName,
              mediaType: row.mediaType,
              title: row.title,
              category: row.category,
              channelId: row.channelId,
              epgChannelId: row.epgChannelId,
              isPinned: _isPinned(pinned, row.playlistId, normalizedCategory),
              relevance: relevance,
            ),
          );
        }
      }

      if (request.tab != SearchResultTab.channels &&
          normalizedCategory.isNotEmpty) {
        final relevance = _matchRelevance(normalizedCategory, query);
        final identity =
            '${row.playlistId}|${row.mediaType}|$normalizedCategory';
        if (relevance != null && seenCategories.add(identity)) {
          categories.add(
            SearchHit(
              type: SearchHitType.category,
              playlistId: row.playlistId,
              playlistName: row.playlistName,
              mediaType: row.mediaType,
              title: row.category,
              category: row.category,
              isPinned: _isPinned(pinned, row.playlistId, normalizedCategory),
              relevance: relevance,
            ),
          );
        }
      }
    }

    _sortHits(channels);
    _sortHits(categories);

    final limit = _boundedLimit(request.limit);
    if (request.tab == SearchResultTab.channels) {
      return channels.take(limit).toList(growable: false);
    }
    if (request.tab == SearchResultTab.categories) {
      return categories.take(limit).toList(growable: false);
    }
    return <SearchHit>[...channels.take(limit), ...categories.take(limit)];
  }

  Future<void> rebuildPlaylist(int playlistId) {
    return _runTracked(() => _rebuildPlaylist(playlistId));
  }

  Future<void> _rebuildPlaylist(int playlistId) async {
    _ensureWritable();
    await _setPlaylistStatus(playlistId, SearchIndexStatus.building);
    try {
      await _db.transaction(() => rebuildPlaylistInTransaction(playlistId));
    } catch (error, stackTrace) {
      await _setPlaylistStatus(playlistId, SearchIndexStatus.failed);
      AppLogger.error(
        'SearchIndexRepository: Failed rebuilding playlist index.',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Rebuilds one playlist while the caller-owned SQLite transaction is open.
  /// Playlist sync uses this boundary so channel replacement and search
  /// document replacement commit or roll back together.
  ///
  /// This boundary deliberately performs no shutdown/writability check: the
  /// caller's transaction is already registered at the lifecycle gate, and an
  /// in-flight transaction must settle atomically instead of aborting
  /// mid-shutdown. New work is rejected at the public entry points.
  Future<void> rebuildPlaylistInTransaction(int playlistId) async {
    final playlist = await _db
        .customSelect(
          'SELECT id FROM playlists WHERE id = ?',
          variables: [Variable<int>(playlistId)],
        )
        .get();
    if (playlist.isEmpty) {
      await _db.customStatement(
        'DELETE FROM search_documents WHERE playlist_id = ?',
        [playlistId],
      );
      await _db.customStatement(
        'DELETE FROM search_index_state WHERE playlist_id = ?',
        [playlistId],
      );
      return;
    }

    await _ensureStateRow(playlistId);
    await _updatePlaylistStatus(playlistId, SearchIndexStatus.building);
    await _db.customStatement(
      'DELETE FROM search_documents WHERE playlist_id = ?',
      [playlistId],
    );

    final channelQuery = _db.selectOnly(_db.channels)
      ..addColumns([
        _db.channels.id,
        _db.channels.playlistId,
        _db.channels.channelType,
        _db.channels.name,
        _db.channels.groupName,
        _db.channels.tvgId,
      ])
      ..where(_db.channels.playlistId.equals(playlistId));
    final channels = await channelQuery.get();

    for (var offset = 0; offset < channels.length; offset += _batchSize) {
      final end = (offset + _batchSize).clamp(0, channels.length);
      final chunk = channels.sublist(offset, end);
      await _db.batch((batch) {
        for (final row in chunk) {
          final channelId = row.read(_db.channels.id)!;
          final mediaType = row.read(_db.channels.channelType)!;
          final title = row.read(_db.channels.name)!;
          final category = normalizeGroupName(row.read(_db.channels.groupName));
          final epgChannelId = row.read(_db.channels.tvgId);
          batch.customStatement(
            '''
INSERT INTO search_documents(
  id,
  playlist_id,
  document_type,
  channel_id,
  media_type,
  title,
  normalized_title,
  category,
  normalized_category,
  epg_channel_id
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
            [
              channelId,
              playlistId,
              _searchDocumentType,
              channelId,
              mediaType,
              title,
              normalizeSearchText(title),
              category,
              normalizeSearchCategory(category),
              epgChannelId,
            ],
          );
        }
      });
    }

    await _db.customStatement(
      '''
UPDATE search_index_state
SET index_format_version = ?,
    sync_revision = sync_revision + 1,
    document_count = ?,
    status = ?,
    updated_at = ?
WHERE playlist_id = ?
''',
      [
        searchIndexFormatVersion,
        channels.length,
        SearchIndexStatus.ready.name,
        DateTime.now().millisecondsSinceEpoch,
        playlistId,
      ],
    );
    if (!_stateChanges.isClosed) _stateChanges.add(null);
  }

  /// Builds missing or stale playlist indexes one at a time. A failed
  /// playlist is isolated so another playlist can still become searchable;
  /// its non-ready state makes it eligible for retry on the next startup.
  Future<void> ensureExistingIndexes({
    Future<void> Function()? betweenPlaylists,
  }) {
    _ensureWritable();
    return _ensureFuture ??= _runTracked(
      () => _ensureExistingIndexes(betweenPlaylists: betweenPlaylists),
    );
  }

  /// Retries every playlist that is not ready without changing the cached
  /// startup future. This is used by the explicit search-field retry action.
  Future<void> retryIncompleteIndexes() {
    _ensureWritable();
    return _retryFuture ??= _runTracked(_runIncompleteIndexRetry);
  }

  /// Registers search and index jobs at the lifecycle gate so shutdown
  /// rejects new work and drains running operations before the SQLite
  /// connection may close.
  Future<T> _runTracked<T>(Future<T> Function() operation) =>
      lifecycleGate?.runTracked(operation) ?? operation();

  Future<void> _runIncompleteIndexRetry() async {
    try {
      final bootstrap = _ensureFuture;
      if (bootstrap != null) await bootstrap;
      await _ensureExistingIndexes();
    } finally {
      _retryFuture = null;
    }
  }

  Stream<SearchIndexBuildState> watchIndexBuildState() {
    return Stream.multi((controller) {
      Timer? timer;
      var cancelled = false;
      var reading = false;

      Future<void> emit() async {
        if (cancelled || reading) return;
        reading = true;
        try {
          final state = await _readBuildState();
          controller.add(state);
          if (state.pendingCount == 0 && state.buildingCount == 0) {
            timer?.cancel();
            timer = null;
          } else {
            timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
              unawaited(emit());
            });
          }
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        } finally {
          reading = false;
        }
      }

      unawaited(emit());
      final subscription = _stateChanges.stream.listen((_) {
        unawaited(emit());
      });
      controller.onCancel = () {
        cancelled = true;
        timer?.cancel();
        unawaited(subscription.cancel());
      };
    });
  }

  Future<void> _ensureExistingIndexes({
    Future<void> Function()? betweenPlaylists,
  }) async {
    _ensureWritable();
    final playlists = await _db
        .customSelect('SELECT id FROM playlists ORDER BY id')
        .get();
    for (final row in playlists) {
      _ensureWritable();
      final playlistId = row.read<int>('id');
      if (!await _playlistNeedsRebuild(playlistId)) continue;
      try {
        await rebuildPlaylist(playlistId);
      } catch (_) {
        // The status was persisted as failed. Continue with the next playlist.
      }
      // Give pending reads and the next Flutter frame a chance to progress
      // before another potentially large playlist transaction starts.
      await Future<void>.delayed(Duration.zero);
      await betweenPlaylists?.call();
    }
  }

  Future<bool> _playlistNeedsRebuild(int playlistId) async {
    final rows = await _db
        .customSelect(
          '''
SELECT
  COALESCE(s.index_format_version, 0) AS index_format_version,
  COALESCE(s.document_count, 0) AS document_count,
  COALESCE(s.status, 'pending') AS status,
  (SELECT COUNT(*) FROM channels c WHERE c.playlist_id = p.id) AS channel_count
FROM playlists p
LEFT JOIN search_index_state s ON s.playlist_id = p.id
WHERE p.id = ?
''',
          variables: [Variable<int>(playlistId)],
        )
        .get();
    if (rows.isEmpty) return false;
    final row = rows.single;
    return row.read<int>('index_format_version') != searchIndexFormatVersion ||
        row.read<int>('document_count') != row.read<int>('channel_count') ||
        row.read<String>('status') != SearchIndexStatus.ready.name;
  }

  Future<SearchIndexBuildState> _readBuildState() async {
    final rows = await _db.customSelect('''
SELECT
  p.id AS playlist_id,
  p.name AS playlist_name,
  COALESCE(s.status, 'pending') AS status,
  COALESCE(s.document_count, 0) AS document_count,
  COALESCE(s.sync_revision, 0) AS sync_revision
FROM playlists p
LEFT JOIN search_index_state s ON s.playlist_id = p.id
ORDER BY lower(p.name), p.id
''').get();
    return SearchIndexBuildState(
      playlists: [
        for (final row in rows)
          SearchIndexPlaylistState(
            playlistId: row.read<int>('playlist_id'),
            playlistName: row.read<String>('playlist_name'),
            status: _parseStatus(row.read<String>('status')),
            documentCount: row.read<int>('document_count'),
            syncRevision: row.read<int>('sync_revision'),
          ),
      ],
    );
  }

  Future<void> _setPlaylistStatus(
    int playlistId,
    SearchIndexStatus status,
  ) async {
    final exists = await _db
        .customSelect(
          'SELECT 1 FROM playlists WHERE id = ?',
          variables: [Variable<int>(playlistId)],
        )
        .get();
    if (exists.isEmpty) return;
    await _ensureStateRow(playlistId);
    await _updatePlaylistStatus(playlistId, status);
  }

  Future<void> _ensureStateRow(int playlistId) async {
    await _db.customStatement(
      '''
INSERT OR IGNORE INTO search_index_state(
  playlist_id,
  index_format_version,
  sync_revision,
  document_count,
  status,
  updated_at
) VALUES (?, ?, 0, 0, ?, ?)
''',
      [
        playlistId,
        searchIndexFormatVersion,
        SearchIndexStatus.pending.name,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> _updatePlaylistStatus(
    int playlistId,
    SearchIndexStatus status,
  ) async {
    await _db.customStatement(
      'UPDATE search_index_state SET status = ?, updated_at = ? '
      'WHERE playlist_id = ?',
      [status.name, DateTime.now().millisecondsSinceEpoch, playlistId],
    );
    if (!_stateChanges.isClosed) _stateChanges.add(null);
  }

  void _ensureWritable() {
    if (_disposed || _shutdownStarted) {
      throw StateError('Search index writes are disabled during shutdown.');
    }
    lifecycleGate?.ensureWritable();
  }

  Future<List<_SearchRow>> _readSearchRows(
    SearchRequest request,
    String query, {
    required int fetchLimit,
  }) async {
    final activeIds = request.activePlaylistIds.toList()..sort();
    final activePlaceholders = List.filled(activeIds.length, '?').join(', ');
    final hidden = _normalizeGroups(request.hiddenGroupsByPlaylist);

    final exactVariables = <Variable<Object>>[
      Variable<String>(query),
      Variable<String>(query),
    ];
    final exactWhere = StringBuffer(
      'WHERE (d.normalized_title = ? OR d.normalized_category = ?) '
      'AND d.playlist_id IN ($activePlaceholders)',
    );
    exactVariables.addAll(activeIds.map(Variable<int>.new));
    _appendHiddenFilters(exactWhere, exactVariables, hidden, activeIds);
    final exactRows = await _db.customSelect('''
SELECT
  d.id AS document_id,
  d.playlist_id,
  p.name AS playlist_name,
  d.channel_id,
  d.media_type,
  d.title,
  d.normalized_title,
  d.category,
  d.normalized_category,
  d.epg_channel_id
FROM search_documents AS d
INNER JOIN playlists AS p ON p.id = d.playlist_id
$exactWhere
LIMIT $fetchLimit
''', variables: exactVariables).get();

    final ftsTable = query.length < 3
        ? 'search_documents_fts_prefix'
        : 'search_documents_fts_trigram';
    final ftsQuery = query.length < 3
        ? '"${_escapeFtsPhrase(query)}"*'
        : '"${_escapeFtsPhrase(query)}"';
    final variables = <Variable<Object>>[Variable<String>(ftsQuery)];
    final where = StringBuffer(
      'WHERE $ftsTable MATCH ? AND d.playlist_id IN ($activePlaceholders)',
    );
    variables.addAll(activeIds.map(Variable<int>.new));
    _appendHiddenFilters(where, variables, hidden, activeIds);

    final ftsRows = await _db.customSelect('''
SELECT
  d.id AS document_id,
  d.playlist_id,
  p.name AS playlist_name,
  d.channel_id,
  d.media_type,
  d.title,
  d.normalized_title,
  d.category,
  d.normalized_category,
  d.epg_channel_id
FROM $ftsTable AS f
INNER JOIN search_documents AS d ON d.id = f.rowid
INNER JOIN playlists AS p ON p.id = d.playlist_id
$where
LIMIT $fetchLimit
''', variables: variables).get();

    return [..._mapSearchRows(exactRows), ..._mapSearchRows(ftsRows)];
  }

  static void _appendHiddenFilters(
    StringBuffer where,
    List<Variable<Object>> variables,
    Map<int, Set<String>> hidden,
    List<int> activeIds,
  ) {
    for (final entry in hidden.entries) {
      if (!activeIds.contains(entry.key) || entry.value.isEmpty) continue;
      final placeholders = List.filled(entry.value.length, '?').join(', ');
      where.write(
        ' AND NOT (d.playlist_id = ? AND d.normalized_category IN ($placeholders))',
      );
      variables.add(Variable<int>(entry.key));
      variables.addAll(entry.value.map(Variable<String>.new));
    }
  }

  List<_SearchRow> _mapSearchRows(Iterable<QueryRow> rows) {
    return [
      for (final row in rows)
        _SearchRow(
          documentId: row.read<int>('document_id'),
          playlistId: row.read<int>('playlist_id'),
          playlistName: row.read<String>('playlist_name'),
          channelId: row.readNullable<int>('channel_id'),
          mediaType: row.read<String>('media_type'),
          title: row.read<String>('title'),
          normalizedTitle: row.read<String>('normalized_title'),
          category: row.read<String>('category'),
          normalizedCategory: row.read<String>('normalized_category'),
          epgChannelId: row.readNullable<String>('epg_channel_id'),
        ),
    ];
  }

  static int _fetchLimit(int requestedLimit) {
    final limit = _boundedLimit(requestedLimit);
    return limit * 64 > 2048 ? 2048 : limit * 64;
  }

  static int _boundedLimit(int value) {
    if (value < 1) return 1;
    if (value > 100) return 100;
    return value;
  }

  static String _escapeFtsPhrase(String value) {
    return value.replaceAll('"', '""');
  }

  static Map<int, Set<String>> _normalizeGroups(Map<int, Set<String>> groups) {
    return {
      for (final entry in groups.entries)
        entry.key: {
          for (final group in entry.value) normalizeSearchCategory(group),
        }..removeWhere((group) => group.isEmpty),
    };
  }

  static bool _isHidden(
    Map<int, Set<String>> hidden,
    int playlistId,
    String category,
  ) {
    return category.isNotEmpty &&
        (hidden[playlistId]?.contains(category) ?? false);
  }

  static bool _isPinned(
    Map<int, Set<String>> pinned,
    int playlistId,
    String category,
  ) {
    return category.isNotEmpty &&
        (pinned[playlistId]?.contains(category) ?? false);
  }

  static int? _matchRelevance(String value, String query) {
    if (value == query) return 0;
    if (value.startsWith(query)) return 1;
    if (RegExp(r'(^|\s)').hasMatch(value) &&
        value.split(' ').skip(1).any((word) => word.startsWith(query))) {
      return 2;
    }
    if (value.contains(query)) return 3;
    return null;
  }

  static void _sortHits(List<SearchHit> hits) {
    hits.sort((a, b) {
      final relevance = a.relevance.compareTo(b.relevance);
      if (relevance != 0) return relevance;
      final pinned = (b.isPinned ? 1 : 0).compareTo(a.isPinned ? 1 : 0);
      if (pinned != 0) return pinned;
      final title = normalizeSearchText(a.title)
          .compareTo(normalizeSearchText(b.title));
      if (title != 0) return title;
      final playlist = normalizeSearchText(a.playlistName)
          .compareTo(normalizeSearchText(b.playlistName));
      if (playlist != 0) return playlist;
      final type = a.mediaType.compareTo(b.mediaType);
      if (type != 0) return type;
      return (a.channelId ?? 0).compareTo(b.channelId ?? 0);
    });
  }

  static SearchIndexStatus _parseStatus(String status) {
    return SearchIndexStatus.values.firstWhere(
      (value) => value.name == status,
      orElse: () => SearchIndexStatus.failed,
    );
  }
}

class _SearchRow {
  const _SearchRow({
    required this.documentId,
    required this.playlistId,
    required this.playlistName,
    required this.channelId,
    required this.mediaType,
    required this.title,
    required this.normalizedTitle,
    required this.category,
    required this.normalizedCategory,
    required this.epgChannelId,
  });

  final int documentId;
  final int playlistId;
  final String playlistName;
  final int? channelId;
  final String mediaType;
  final String title;
  final String normalizedTitle;
  final String category;
  final String normalizedCategory;
  final String? epgChannelId;
}
