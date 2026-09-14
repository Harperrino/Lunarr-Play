import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/search/search_index_repository.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';

void main() {
  test(
    'SQLite search supports prefixes, trigrams, Unicode and safe syntax',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PlaylistRepository(database);
      final playlistId = await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Search playlist',
          type: 'm3u',
          urlOrHost: 'not stored in search index',
        ),
      );
      await repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: const [
          ParsedChannel(
            name: 'News HD',
            streamUrl: 'https://example.invalid/news',
            groupName: 'Nachrichten',
            channelType: 'live',
          ),
          ParsedChannel(
            name: 'Ärzte München',
            streamUrl: 'https://example.invalid/muenchen',
            groupName: 'Kultur',
            channelType: 'live',
          ),
          ParsedChannel(
            name: 'News Movie',
            streamUrl: 'https://example.invalid/movie',
            groupName: 'Nachrichten',
            channelType: 'vod',
          ),
        ],
      );

      final search = SearchIndexRepository(database);
      SearchRequest base(String query, SearchResultTab tab) {
        return SearchRequest(
          query: query,
          tab: tab,
          activePlaylistIds: {playlistId},
          limit: 12,
        );
      }

      final prefixHits = await search.search(
        base('ne', SearchResultTab.channels),
      );
      expect(prefixHits.map((hit) => hit.title), contains('News HD'));
      final trigramHits = await search.search(
        base('ews', SearchResultTab.channels),
      );
      expect(trigramHits.map((hit) => hit.title), contains('News HD'));
      final umlautHits = await search.search(
        base('mü', SearchResultTab.channels),
      );
      expect(umlautHits.single.title, 'Ärzte München');

      final categoryHits = await search.search(
        base('na', SearchResultTab.categories),
      );
      expect(categoryHits, hasLength(2));
      expect(categoryHits.map((hit) => hit.title), everyElement('Nachrichten'));
      expect(
        await search.search(base('" OR MATCH *', SearchResultTab.all)),
        isEmpty,
      );
    },
  );

  test('exact title matches rank before broader FTS matches', () async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PlaylistRepository(database);
    final playlistId = await repository.insertPlaylist(
      PlaylistsCompanion.insert(
        name: 'Ranking',
        type: 'm3u',
        urlOrHost: 'https://example.invalid/ranking',
      ),
    );
    await repository.syncM3uChannels(
      playlistId: playlistId,
      parsedChannels: const [
        ParsedChannel(
          name: 'News Magazine',
          streamUrl: 'https://example.invalid/magazine',
          groupName: 'News',
          channelType: 'live',
        ),
        ParsedChannel(
          name: 'News',
          streamUrl: 'https://example.invalid/exact',
          groupName: 'News',
          channelType: 'live',
        ),
        ParsedChannel(
          name: 'World News',
          streamUrl: 'https://example.invalid/world',
          groupName: 'News',
          channelType: 'live',
        ),
      ],
    );

    final hits = await SearchIndexRepository(database).search(
      SearchRequest(
        query: 'news',
        tab: SearchResultTab.channels,
        activePlaylistIds: {playlistId},
      ),
    );
    expect(hits.first.title, 'News');
    expect(hits.first.relevance, 0);
  });

  test(
    'visibility and pinning are query-time filters over compact hits',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PlaylistRepository(database);
      final firstId = await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'First',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/first',
        ),
      );
      final secondId = await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Second',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/second',
        ),
      );
      await repository.syncM3uChannels(
        playlistId: firstId,
        parsedChannels: const [
          ParsedChannel(
            name: 'News One',
            streamUrl: 'https://example.invalid/one',
            groupName: 'News',
            channelType: 'live',
          ),
          ParsedChannel(
            name: 'News Two',
            streamUrl: 'https://example.invalid/two',
            groupName: 'Sports',
            channelType: 'live',
          ),
        ],
      );
      await repository.syncM3uChannels(
        playlistId: secondId,
        parsedChannels: const [
          ParsedChannel(
            name: 'News Three',
            streamUrl: 'https://example.invalid/three',
            groupName: 'News',
            channelType: 'live',
          ),
        ],
      );

      final hits = await SearchIndexRepository(database).search(
        SearchRequest(
          query: 'news',
          tab: SearchResultTab.channels,
          activePlaylistIds: {firstId, secondId},
          hiddenGroupsByPlaylist: {
            firstId: {'News'},
          },
          pinnedGroupsByPlaylist: {
            firstId: {'Sports'},
          },
        ),
      );
      expect(hits.map((hit) => hit.title), ['News Two', 'News Three']);
      expect(hits.first.isPinned, isTrue);
    },
  );

  test(
    'failed atomic sync rolls channels and search documents back together',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PlaylistRepository(database);
      final playlistId = await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Atomic',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/atomic',
        ),
      );
      await repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: const [
          ParsedChannel(
            name: 'Stable News',
            streamUrl: 'https://example.invalid/stable',
            groupName: 'News',
            channelType: 'live',
          ),
        ],
      );
      await database.customStatement('''
CREATE TRIGGER fail_search_sync
BEFORE INSERT ON search_documents
WHEN new.title = 'Boom'
BEGIN
  SELECT RAISE(ABORT, 'forced search index failure');
END;
''');

      await expectLater(
        repository.syncM3uChannels(
          playlistId: playlistId,
          parsedChannels: const [
            ParsedChannel(
              name: 'Boom',
              streamUrl: 'https://example.invalid/boom',
              groupName: 'News',
              channelType: 'live',
            ),
          ],
        ),
        throwsA(isA<Object>()),
      );
      await database.customStatement('DROP TRIGGER fail_search_sync');

      final channels = await repository
          .watchChannelsByPlaylist(playlistId)
          .first;
      expect(channels.single.name, 'Stable News');
      final hits = await SearchIndexRepository(database).search(
        SearchRequest(
          query: 'stable',
          tab: SearchResultTab.channels,
          activePlaylistIds: {playlistId},
        ),
      );
      expect(hits.single.title, 'Stable News');
    },
  );

  test(
    'existing channels get a ready index sequentially after bootstrap',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final playlistId = await database
          .into(database.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Existing',
              type: 'm3u',
              urlOrHost: 'https://example.invalid/existing',
            ),
          );
      await database
          .into(database.channels)
          .insert(
            ChannelsCompanion.insert(
              playlistId: playlistId,
              name: 'Existing News',
              streamUrl: 'https://example.invalid/existing-news',
              groupName: const Value('News'),
              channelType: 'live',
            ),
          );

      final search = SearchIndexRepository(database);
      await search.ensureExistingIndexes();
      final state = await database
          .customSelect(
            'SELECT status, document_count FROM search_index_state '
            'WHERE playlist_id = ?',
            variables: [Variable<int>(playlistId)],
          )
          .getSingle();
      expect(state.read<String>('status'), 'ready');
      expect(state.read<int>('document_count'), 1);
      expect(
        (await search.search(
          SearchRequest(
            query: 'existing',
            tab: SearchResultTab.channels,
            activePlaylistIds: {playlistId},
          ),
        )).single.title,
        'Existing News',
      );
    },
  );

  test('bootstrap isolates a failed playlist and retries non-ready state', () async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    final brokenId = await database
        .into(database.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Broken',
            type: 'm3u',
            urlOrHost: 'https://example.invalid/broken',
          ),
        );
    final readyId = await database
        .into(database.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Ready',
            type: 'm3u',
            urlOrHost: 'https://example.invalid/ready',
          ),
        );
    await database.batch((batch) {
      batch.insert(
        database.channels,
        ChannelsCompanion.insert(
          playlistId: brokenId,
          name: 'Broken News',
          streamUrl: 'https://example.invalid/broken-news',
          groupName: const Value('News'),
          channelType: 'live',
        ),
      );
      batch.insert(
        database.channels,
        ChannelsCompanion.insert(
          playlistId: readyId,
          name: 'Ready News',
          streamUrl: 'https://example.invalid/ready-news',
          groupName: const Value('News'),
          channelType: 'live',
        ),
      );
    });
    await database.customStatement('''
CREATE TRIGGER fail_one_playlist
BEFORE INSERT ON search_documents
WHEN new.playlist_id = $brokenId
BEGIN
  SELECT RAISE(ABORT, 'forced broken playlist');
END;
''');

    final search = SearchIndexRepository(database);
    await search.ensureExistingIndexes();
    await database.customStatement('DROP TRIGGER fail_one_playlist');

    final states = await database
        .customSelect(
          'SELECT playlist_id, status FROM search_index_state '
          'ORDER BY playlist_id',
        )
        .get();
    expect(states.map((row) => row.read<String>('status')), [
      'failed',
      'ready',
    ]);
    expect(
      (await search.search(
        SearchRequest(
          query: 'ready',
          tab: SearchResultTab.channels,
          activePlaylistIds: {readyId},
        ),
      )).single.title,
      'Ready News',
    );

    // The cached future models one bootstrap run. A fresh repository models
    // the next startup and retries the failed playlist once its cause is gone.
    await search.ensureExistingIndexes();
    final cachedRetry = await database
        .customSelect(
          'SELECT status FROM search_index_state WHERE playlist_id = ?',
          variables: [Variable<int>(brokenId)],
        )
        .getSingle();
    expect(cachedRetry.read<String>('status'), 'failed');

    final restartedSearch = SearchIndexRepository(database);
    await restartedSearch.ensureExistingIndexes();
    final resumed = await database
        .customSelect(
          'SELECT status FROM search_index_state WHERE playlist_id = ?',
          variables: [Variable<int>(brokenId)],
        )
        .getSingle();
    expect(resumed.read<String>('status'), 'ready');
  });

  test(
    'playlist deletion cascades search state, documents and FTS rows',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = PlaylistRepository(database);
      final playlistId = await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Delete me',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/delete',
        ),
      );
      await repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: const [
          ParsedChannel(
            name: 'Delete News',
            streamUrl: 'https://example.invalid/delete-news',
            groupName: 'News',
            channelType: 'live',
          ),
        ],
      );

      await repository.deletePlaylist(playlistId);
      for (final table in const [
        'search_documents',
        'search_index_state',
        'search_documents_fts_trigram',
        'search_documents_fts_prefix',
      ]) {
        final count = await database
            .customSelect('SELECT COUNT(*) AS count FROM $table')
            .map((row) => row.read<int>('count'))
            .getSingle();
        expect(count, 0, reason: 'Rows remain in $table');
      }
    },
  );
}
