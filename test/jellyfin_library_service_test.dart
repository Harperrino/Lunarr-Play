import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_library_service.dart';

import 'jellyfin_test_helpers.dart';

void main() {
  group('JellyfinLibraryService', () {
    test('loads all home sections from their endpoints', () async {
      final service = JellyfinLibraryService(
        apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      );

      final home = await service.fetchHomeData(jellyfinTestConnection);

      expect(home.libraries, hasLength(2));
      expect(home.libraries.first.name, 'Movies');
      expect(home.libraries.first.isMovies, isTrue);
      expect(home.resumeItems, hasLength(1));
      expect(home.resumeItems.first.name, 'Test Movie');
      expect(home.resumeItems.first.hasResume, isTrue);
      expect(home.nextUpItems, hasLength(1));
      expect(home.nextUpItems.first.isEpisode, isTrue);
      expect(home.latestItems, hasLength(1));
      expect(home.latestItems.first.name, 'New Movie');
    });

    test('degrades broken sections to empty lists', () async {
      final service = JellyfinLibraryService(
        apiClient: JellyfinApiClient(
          transport: jellyfinHappyTransport(
            failResume: true,
            failNextUp: true,
            failLatest: true,
          ),
        ),
      );

      final home = await service.fetchHomeData(jellyfinTestConnection);

      expect(home.resumeItems, isEmpty);
      expect(home.nextUpItems, isEmpty);
      expect(home.latestItems, isEmpty);
      expect(home.libraries, hasLength(2));
    });

    test('a failing library list fails the whole home request', () async {
      final service = JellyfinLibraryService(
        apiClient: JellyfinApiClient(
          transport: jellyfinHappyTransport(failViews: true),
        ),
      );

      await expectLater(
        service.fetchHomeData(jellyfinTestConnection),
        throwsA(isA<Object>()),
      );
    });

    test('library items are filtered by the collection type', () async {
      var requestedTypes = '';
      final baseHandler = jellyfinHappyHandler();
      final service = JellyfinLibraryService(
        apiClient: JellyfinApiClient(
          transport: MockClient((request) async {
            if (request.url.path.endsWith('/Users/user-id-1/Items')) {
              requestedTypes =
                  request.url.queryParameters['IncludeItemTypes'] ?? '';
            }
            return baseHandler(request);
          }),
        ),
      );

      final movies = await service.fetchLibraryItems(
        jellyfinTestConnection,
        JellyfinLibrary.fromJson(jellyfinLibraryJson()),
      );
      expect(movies, hasLength(2));
      expect(requestedTypes, 'Movie');
    });

    test('mixed libraries request movies and series', () async {
      final service = JellyfinLibraryService(
        apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      );

      final items = await service.fetchLibraryItems(
        jellyfinTestConnection,
        JellyfinLibrary.fromJson(jellyfinLibraryJson(collectionType: 'mixed')),
      );
      expect(items, hasLength(2));
    });

    test('episodes parse with season metadata', () async {
      final service = JellyfinLibraryService(
        apiClient: JellyfinApiClient(transport: jellyfinHappyTransport()),
      );

      final episodes = await service.fetchSeriesEpisodes(
        jellyfinTestConnection,
        'series-1',
      );
      expect(episodes, hasLength(2));
      expect(episodes.first.seasonNumber, 1);
      expect(episodes.first.episodeNumber, 2);
    });
  });
}
