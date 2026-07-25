import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/search/search_index_repository.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';

const _runSearchIndexPerformance = bool.fromEnvironment('SEARCH_INDEX_PERF');

void main() {
  test(
    '100k-document warm search stays bounded and returns only the requested hits',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final playlistId = await database
          .into(database.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Performance',
              type: 'm3u',
              urlOrHost: 'https://example.invalid/performance',
            ),
          );

      const documentCount = 100000;
      for (var offset = 0; offset < documentCount; offset += 1000) {
        final end = (offset + 1000).clamp(0, documentCount);
        await database.batch((batch) {
          for (var index = offset; index < end; index++) {
            final title = 'Channel $index';
            batch.customStatement(
              '''
INSERT INTO search_documents(
  id, playlist_id, document_type, media_type, title,
  normalized_title, category, normalized_category
) VALUES (?, ?, 'channel', 'live', ?, ?, 'Performance', 'performance')
''',
              [index + 1, playlistId, title, title.toLowerCase()],
            );
          }
        });
      }

      final search = SearchIndexRepository(database);
      final samples = <int>[];
      for (var sample = 0; sample < 12; sample++) {
        final stopwatch = Stopwatch()..start();
        final hits = await search.search(
          SearchRequest(
            query: 'performance',
            tab: SearchResultTab.categories,
            activePlaylistIds: {playlistId},
            limit: 12,
          ),
        );
        stopwatch.stop();
        expect(hits, hasLength(1));
        samples.add(stopwatch.elapsedMilliseconds);
      }
      samples.sort();
      final p95 =
          samples[(samples.length * 95 ~/ 100).clamp(0, samples.length - 1)];
      expect(p95, lessThan(50));
    },
    skip: _runSearchIndexPerformance
        ? false
        : 'Enable with --dart-define=SEARCH_INDEX_PERF=true',
  );
}
