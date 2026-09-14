import 'package:drift/drift.dart';

const searchIndexFormatVersion = 1;

const _searchDocumentsTable = 'search_documents';
const _searchIndexStateTable = 'search_index_state';
const _searchTrigramTable = 'search_documents_fts_trigram';
const _searchPrefixTable = 'search_documents_fts_prefix';

const _searchTriggerNames = <String>{
  'search_documents_ai',
  'search_documents_ad',
  'search_documents_au',
  'search_documents_channel_ad',
  'search_index_state_playlist_ai',
};

Future<void> ensureSearchSchema(GeneratedDatabase database) async {
  await database.customStatement('''
CREATE TABLE IF NOT EXISTS search_documents (
  id INTEGER PRIMARY KEY,
  playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL,
  channel_id INTEGER REFERENCES channels(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL,
  title TEXT NOT NULL,
  normalized_title TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT '',
  normalized_category TEXT NOT NULL DEFAULT '',
  epg_channel_id TEXT
);
''');
  await database.customStatement('''
CREATE TABLE IF NOT EXISTS search_index_state (
  playlist_id INTEGER PRIMARY KEY REFERENCES playlists(id) ON DELETE CASCADE,
  index_format_version INTEGER NOT NULL DEFAULT $searchIndexFormatVersion,
  sync_revision INTEGER NOT NULL DEFAULT 0,
  document_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  updated_at INTEGER NOT NULL DEFAULT 0
);
''');

  await _validateTableColumns(database, _searchDocumentsTable, const {
    'id': 'INTEGER',
    'playlist_id': 'INTEGER',
    'document_type': 'TEXT',
    'channel_id': 'INTEGER',
    'media_type': 'TEXT',
    'title': 'TEXT',
    'normalized_title': 'TEXT',
    'category': 'TEXT',
    'normalized_category': 'TEXT',
    'epg_channel_id': 'TEXT',
  });
  await _validateTableColumns(database, _searchIndexStateTable, const {
    'playlist_id': 'INTEGER',
    'index_format_version': 'INTEGER',
    'sync_revision': 'INTEGER',
    'document_count': 'INTEGER',
    'status': 'TEXT',
    'updated_at': 'INTEGER',
  });

  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_search_documents_playlist '
    'ON search_documents (playlist_id, media_type, normalized_title);',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_search_documents_channel '
    'ON search_documents (channel_id);',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_search_documents_category '
    'ON search_documents (playlist_id, normalized_category);',
  );

  var needsTrigramRebuild = await _ensureVirtualTable(
    database,
    _searchTrigramTable,
    '''
CREATE VIRTUAL TABLE IF NOT EXISTS search_documents_fts_trigram USING fts5(
  normalized_title,
  normalized_category,
  content='search_documents',
  content_rowid='id',
  tokenize='trigram'
);
''',
  );
  var needsPrefixRebuild = await _ensureVirtualTable(
    database,
    _searchPrefixTable,
    '''
CREATE VIRTUAL TABLE IF NOT EXISTS search_documents_fts_prefix USING fts5(
  normalized_title,
  normalized_category,
  content='search_documents',
  content_rowid='id',
  prefix='1 2',
  tokenize='unicode61 remove_diacritics 0'
);
''',
  );

  for (final trigger in _searchTriggerNames) {
    final exists = await _sqliteObjectExists(database, trigger);
    if (!exists) {
      needsTrigramRebuild = true;
      needsPrefixRebuild = true;
    }
  }

  await database.customStatement('''
CREATE TRIGGER IF NOT EXISTS search_documents_ai
AFTER INSERT ON search_documents
BEGIN
  INSERT INTO search_documents_fts_trigram(rowid, normalized_title, normalized_category)
  VALUES (new.id, new.normalized_title, new.normalized_category);
  INSERT INTO search_documents_fts_prefix(rowid, normalized_title, normalized_category)
  VALUES (new.id, new.normalized_title, new.normalized_category);
END;
''');
  await database.customStatement('''
CREATE TRIGGER IF NOT EXISTS search_documents_ad
AFTER DELETE ON search_documents
BEGIN
  INSERT INTO search_documents_fts_trigram(
    search_documents_fts_trigram,
    rowid,
    normalized_title,
    normalized_category
  ) VALUES ('delete', old.id, old.normalized_title, old.normalized_category);
  INSERT INTO search_documents_fts_prefix(
    search_documents_fts_prefix,
    rowid,
    normalized_title,
    normalized_category
  ) VALUES ('delete', old.id, old.normalized_title, old.normalized_category);
END;
''');
  await database.customStatement('''
CREATE TRIGGER IF NOT EXISTS search_documents_au
AFTER UPDATE ON search_documents
BEGIN
  INSERT INTO search_documents_fts_trigram(
    search_documents_fts_trigram,
    rowid,
    normalized_title,
    normalized_category
  ) VALUES ('delete', old.id, old.normalized_title, old.normalized_category);
  INSERT INTO search_documents_fts_prefix(
    search_documents_fts_prefix,
    rowid,
    normalized_title,
    normalized_category
  ) VALUES ('delete', old.id, old.normalized_title, old.normalized_category);
  INSERT INTO search_documents_fts_trigram(rowid, normalized_title, normalized_category)
  VALUES (new.id, new.normalized_title, new.normalized_category);
  INSERT INTO search_documents_fts_prefix(rowid, normalized_title, normalized_category)
  VALUES (new.id, new.normalized_title, new.normalized_category);
END;
''');
  await database.customStatement('''
CREATE TRIGGER IF NOT EXISTS search_documents_channel_ad
AFTER DELETE ON channels
BEGIN
  DELETE FROM search_documents WHERE channel_id = old.id;
END;
''');
  await database.customStatement('''
CREATE TRIGGER IF NOT EXISTS search_index_state_playlist_ai
AFTER INSERT ON playlists
BEGIN
  INSERT OR IGNORE INTO search_index_state(playlist_id)
  VALUES (new.id);
END;
''');

  await database.customStatement('''
INSERT OR IGNORE INTO search_index_state(
  playlist_id,
  index_format_version,
  sync_revision,
  document_count,
  status,
  updated_at
)
SELECT id, $searchIndexFormatVersion, 0, 0, 'pending', 0
FROM playlists;
''');

  if (needsTrigramRebuild ||
      await _ftsCount(database, _searchTrigramTable) !=
          await _documentCount(database)) {
    await database.customStatement(
      "INSERT INTO search_documents_fts_trigram(search_documents_fts_trigram) VALUES ('rebuild');",
    );
    needsTrigramRebuild = false;
  }
  if (needsPrefixRebuild ||
      await _ftsCount(database, _searchPrefixTable) !=
          await _documentCount(database)) {
    await database.customStatement(
      "INSERT INTO search_documents_fts_prefix(search_documents_fts_prefix) VALUES ('rebuild');",
    );
  }
}

Future<void> _validateTableColumns(
  GeneratedDatabase database,
  String tableName,
  Map<String, String> expected,
) async {
  final rows = await database
      .customSelect('PRAGMA table_info($tableName)')
      .get();
  final actual = <String, String>{
    for (final row in rows)
      row.read<String>('name'): row.read<String>('type').trim().toUpperCase(),
  };
  final missing = expected.keys.where((name) => !actual.containsKey(name));
  if (missing.isNotEmpty) {
    throw StateError(
      'Search schema table $tableName is incomplete; missing columns: '
      '${missing.join(', ')}. No table rebuild was attempted.',
    );
  }
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) {
      throw StateError(
        'Search schema table $tableName has incompatible column '
        '${entry.key}; expected ${entry.value}, got ${actual[entry.key]}.',
      );
    }
  }
}

Future<bool> _ensureVirtualTable(
  GeneratedDatabase database,
  String name,
  String createSql,
) async {
  final objectType = await _sqliteObjectType(database, name);
  if (objectType != null && objectType != 'table') {
    throw StateError(
      'Search schema object $name exists as $objectType instead of an FTS5 table.',
    );
  }
  if (objectType == null) {
    await database.customStatement(createSql);
    return true;
  }
  return false;
}

Future<bool> _sqliteObjectExists(
  GeneratedDatabase database,
  String name,
) async {
  return await _sqliteObjectType(database, name) != null;
}

Future<String?> _sqliteObjectType(
  GeneratedDatabase database,
  String name,
) async {
  final rows = await database
      .customSelect(
        'SELECT type FROM sqlite_master WHERE name = ?',
        variables: [Variable<String>(name)],
      )
      .get();
  if (rows.isEmpty) return null;
  return rows.first.read<String>('type');
}

Future<int> _documentCount(GeneratedDatabase database) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM search_documents')
      .getSingle();
  return row.read<int>('count');
}

Future<int> _ftsCount(GeneratedDatabase database, String tableName) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $tableName')
      .getSingle();
  return row.read<int>('count');
}
