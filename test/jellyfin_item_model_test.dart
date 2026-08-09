import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';

void main() {
  group('JellyfinItem.fromJson', () {
    test('parses all supported fields', () {
      final item = JellyfinItem.fromJson({
        'Id': 'item-1',
        'Name': 'Movie One',
        'Type': 'Movie',
        'SeriesId': 'series-1',
        'SeriesName': 'A Series',
        'ParentIndexNumber': 3,
        'IndexNumber': 7,
        'ProductionYear': 2021,
        'Overview': 'A long overview.',
        'RunTimeTicks': 100000000,
        'ImageTags': {'Primary': 'tag-primary', 'Logo': 'tag-logo'},
        'BackdropImageTags': ['tag-backdrop'],
        'OfficialRating': 'PG-13',
        'CommunityRating': 7.4,
        'CriticRating': 74,
        'ProviderIds': {'Imdb': 'tt123', 'Tmdb': '456'},
        'Genres': ['Drama', 'Fantasy'],
        'Taglines': ['A journey beyond the stars.'],
        'Studios': [
          {'Name': 'Lunarr Pictures'},
        ],
        'People': [
          {'Name': 'Director One', 'Type': 'Director'},
          {'Name': 'Writer One', 'Role': 'Writer'},
        ],
        'RemoteTrailers': [
          {'Name': 'Official trailer', 'Url': 'https://example.com/trailer'},
        ],
        'UserData': {
          'PlaybackPositionTicks': 25000000,
          'Played': false,
          'IsFavorite': true,
        },
      });

      expect(item.id, 'item-1');
      expect(item.name, 'Movie One');
      expect(item.type, 'Movie');
      expect(item.seriesId, 'series-1');
      expect(item.seriesName, 'A Series');
      expect(item.seasonNumber, 3);
      expect(item.episodeNumber, 7);
      expect(item.productionYear, 2021);
      expect(item.overview, 'A long overview.');
      expect(item.runTimeTicks, 100000000);
      expect(item.playbackPositionTicks, 25000000);
      expect(item.played, isFalse);
      expect(item.favorite, isTrue);
      expect(item.primaryImageTag, 'tag-primary');
      expect(item.logoImageTag, 'tag-logo');
      expect(item.backdropImageTag, 'tag-backdrop');
      expect(item.backdropItemId, isNull);
      expect(item.officialRating, 'PG-13');
      expect(item.communityRating, 7.4);
      expect(item.criticRating, 74);
      expect(item.providerIds, {'Imdb': 'tt123', 'Tmdb': '456'});
      expect(item.genres, ['Drama', 'Fantasy']);
      expect(item.taglines, ['A journey beyond the stars.']);
      expect(item.studios, ['Lunarr Pictures']);
      expect(item.people.map((person) => person.name), [
        'Director One',
        'Writer One',
      ]);
      expect(item.remoteTrailers.single.url, 'https://example.com/trailer');
      expect(item.hasResume, isTrue);
      expect(item.resumeFraction, closeTo(0.25, 0.001));
    });

    test('ignores unknown fields and missing members', () {
      final item = JellyfinItem.fromJson({
        'Id': 'item-2',
        'Name': 'Empty Item',
        'Type': 'Movie',
        'FutureServerField': {'anything': true},
      });

      expect(item.id, 'item-2');
      expect(item.name, 'Empty Item');
      expect(item.seasonNumber, isNull);
      expect(item.episodeNumber, isNull);
      expect(item.productionYear, isNull);
      expect(item.overview, '');
      expect(item.runTimeTicks, 0);
      expect(item.playbackPositionTicks, 0);
      expect(item.played, isFalse);
      expect(item.favorite, isFalse);
      expect(item.primaryImageTag, isNull);
      expect(item.backdropImageTag, isNull);
      expect(item.genres, isEmpty);
      expect(item.hasResume, isFalse);
    });

    test('supports top-level image tags and played flags', () {
      final item = JellyfinItem.fromJson({
        'Id': 'item-3',
        'Name': 'Watched',
        'Type': 'Episode',
        'PrimaryImageTag': 'top-primary',
        'BackdropImageTag': 'top-backdrop',
        'UserData': {'Played': true},
      });

      expect(item.primaryImageTag, 'top-primary');
      expect(item.backdropImageTag, 'top-backdrop');
      expect(item.played, isTrue);
      expect(item.hasResume, isFalse);
    });

    test('uses inherited series backdrop artwork for episodes', () {
      final item = JellyfinItem.fromJson({
        'Id': 'episode-1',
        'Type': 'Episode',
        'SeriesId': 'series-1',
        'ParentBackdropItemId': 'series-1',
        'ParentBackdropImageTags': ['series-backdrop-tag'],
      });

      expect(item.backdropImageTag, 'series-backdrop-tag');
      expect(item.backdropItemId, 'series-1');
      expect(item.seriesId, 'series-1');
    });

    test('prefers an item backdrop over inherited artwork', () {
      final item = JellyfinItem.fromJson({
        'Id': 'episode-2',
        'Type': 'Episode',
        'SeriesId': 'series-1',
        'ParentBackdropItemId': 'series-1',
        'BackdropImageTags': ['episode-backdrop'],
        'ParentBackdropImageTags': ['series-backdrop'],
      });

      expect(item.backdropImageTag, 'episode-backdrop');
      expect(item.backdropItemId, isNull);
    });

    test('type helpers distinguish media kinds', () {
      expect(JellyfinItem.fromJson({'Type': 'Movie'}).isMovie, isTrue);
      expect(JellyfinItem.fromJson({'Type': 'Series'}).isSeries, isTrue);
      expect(JellyfinItem.fromJson({'Type': 'Episode'}).isEpisode, isTrue);
    });
  });

  group('JellyfinLibrary.fromJson', () {
    test('parses identity and collection type', () {
      final library = JellyfinLibrary.fromJson({
        'Id': 'lib-1',
        'Name': 'Movies',
        'CollectionType': 'movies',
        'ImageTags': {'Primary': 'tag'},
      });

      expect(library.id, 'lib-1');
      expect(library.name, 'Movies');
      expect(library.collectionType, 'movies');
      expect(library.imageTag, 'tag');
      expect(library.isMovies, isTrue);
      expect(library.isTvShows, isFalse);
    });

    test('defaults missing members and ignores unknown fields', () {
      final library = JellyfinLibrary.fromJson({'Id': 'lib-2'});
      expect(library.name, '');
      expect(library.collectionType, '');
      expect(library.imageTag, isNull);
      expect(library.isMovies, isFalse);
    });
  });
}
