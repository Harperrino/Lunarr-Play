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
        'SeriesName': 'A Series',
        'ParentIndexNumber': 3,
        'IndexNumber': 7,
        'ProductionYear': 2021,
        'Overview': 'A long overview.',
        'RunTimeTicks': 100000000,
        'ImageTags': {'Primary': 'tag-primary', 'Backdrop': 'tag-backdrop'},
        'UserData': {'PlaybackPositionTicks': 25000000, 'Played': false},
      });

      expect(item.id, 'item-1');
      expect(item.name, 'Movie One');
      expect(item.type, 'Movie');
      expect(item.seriesName, 'A Series');
      expect(item.seasonNumber, 3);
      expect(item.episodeNumber, 7);
      expect(item.productionYear, 2021);
      expect(item.overview, 'A long overview.');
      expect(item.runTimeTicks, 100000000);
      expect(item.playbackPositionTicks, 25000000);
      expect(item.played, isFalse);
      expect(item.primaryImageTag, 'tag-primary');
      expect(item.backdropImageTag, 'tag-backdrop');
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
      expect(item.primaryImageTag, isNull);
      expect(item.backdropImageTag, isNull);
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
