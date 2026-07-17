import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PlaylistRepository repository;
  late int playlistId;

  setUp(() async {
    db = AppDatabase.executor(NativeDatabase.memory());
    repository = PlaylistRepository(db);
    playlistId = await repository.insertPlaylist(
      const PlaylistsCompanion(
        name: Value('Favorites Test'),
        type: Value('m3u'),
        urlOrHost: Value('redacted-test-source'),
      ),
    );
  });

  tearDown(() => db.close());

  test('identity prefers nonempty stream ID and otherwise uses URL', () {
    expect(
      channelFavoriteIdentity(
        channelType: ' live ',
        streamId: ' 42 ',
        streamUrl: 'https://old.invalid/live',
      ),
      channelFavoriteIdentity(
        channelType: 'live',
        streamId: '42',
        streamUrl: 'https://new.invalid/live',
      ),
    );
    expect(
      channelFavoriteIdentity(
        channelType: 'live',
        streamId: '  ',
        streamUrl: ' https://example.invalid/live ',
      ),
      channelFavoriteIdentity(
        channelType: 'live',
        streamId: null,
        streamUrl: 'https://example.invalid/live',
      ),
    );
    expect(
      channelFavoriteIdentity(
        channelType: 'vod',
        streamId: '42',
        streamUrl: 'https://example.invalid/live',
      ),
      isNot(
        channelFavoriteIdentity(
          channelType: 'live',
          streamId: '42',
          streamUrl: 'https://example.invalid/live',
        ),
      ),
    );
  });

  test('watch later identity follows the same stable source contract', () {
    expect(
      channelWatchLaterIdentity(
        channelType: ' series ',
        streamId: ' 42 ',
        streamUrl: 'https://old.invalid/series',
      ),
      channelWatchLaterIdentity(
        channelType: 'series',
        streamId: '42',
        streamUrl: 'https://new.invalid/series',
      ),
    );
    expect(
      channelWatchLaterIdentity(
        channelType: 'vod',
        streamId: '42',
        streamUrl: 'https://example.invalid/movie',
      ),
      isNot(
        channelWatchLaterIdentity(
          channelType: 'series',
          streamId: '42',
          streamUrl: 'https://example.invalid/movie',
        ),
      ),
    );
  });

  test('toggle persists and emits through repository watch', () async {
    await repository.syncM3uChannels(
      playlistId: playlistId,
      parsedChannels: const [
        ParsedChannel(
          name: 'Reactive Live',
          streamUrl: 'https://example.invalid/reactive.m3u8',
          channelType: 'live',
        ),
      ],
    );

    final emissions = <List<Channel>>[];
    final favoriteSeen = Completer<void>();
    final subscription = repository.watchChannelsByPlaylist(playlistId).listen((
      channels,
    ) {
      emissions.add(channels);
      if (channels.length == 1 &&
          channels.single.isFavorite &&
          !favoriteSeen.isCompleted) {
        favoriteSeen.complete();
      }
    });
    addTearDown(subscription.cancel);

    final channel = (await db.select(db.channels).get()).single;
    expect(await repository.toggleChannelFavorite(channel.id), isTrue);
    await favoriteSeen.future.timeout(const Duration(seconds: 2));

    expect(emissions.last.single.isFavorite, isTrue);
    expect(await repository.toggleChannelFavorite(channel.id), isFalse);
  });

  test('sync preserves stable favorites and removes stale channels', () async {
    await repository.syncM3uChannels(
      playlistId: playlistId,
      parsedChannels: const [
        ParsedChannel(
          name: 'Xtream Old Name',
          streamUrl: 'https://old.invalid/42',
          channelType: 'live',
          streamId: '42',
        ),
        ParsedChannel(
          name: 'Plain M3U',
          streamUrl: 'https://example.invalid/plain.m3u8',
          channelType: 'live',
        ),
        ParsedChannel(
          name: 'Removed',
          streamUrl: 'https://example.invalid/removed.m3u8',
          channelType: 'live',
        ),
      ],
    );
    final initial = await db.select(db.channels).get();
    for (final channel in initial) {
      await repository.toggleChannelFavorite(channel.id);
    }

    await repository.syncM3uChannels(
      playlistId: playlistId,
      parsedChannels: const [
        ParsedChannel(
          name: 'Xtream Renamed',
          streamUrl: 'https://new.invalid/42',
          channelType: 'live',
          streamId: '42',
        ),
        ParsedChannel(
          name: 'Plain M3U Renamed',
          streamUrl: 'https://example.invalid/plain.m3u8',
          channelType: 'live',
          tvgId: 'changed-epg-id',
        ),
        ParsedChannel(
          name: 'New Channel',
          streamUrl: 'https://example.invalid/new.m3u8',
          channelType: 'live',
        ),
      ],
    );

    final synced = await db.select(db.channels).get();
    expect(synced, hasLength(3));
    expect(
      synced
          .firstWhere((channel) => channel.name == 'Xtream Renamed')
          .isFavorite,
      isTrue,
    );
    expect(
      synced
          .firstWhere((channel) => channel.name == 'Plain M3U Renamed')
          .isFavorite,
      isTrue,
    );
    expect(
      synced.firstWhere((channel) => channel.name == 'New Channel').isFavorite,
      isFalse,
    );
    expect(synced.where((channel) => channel.name == 'Removed'), isEmpty);
  });

  test(
    'watch later toggles, filters to catalogue types, and survives sync',
    () async {
      await repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: const [
          ParsedChannel(
            name: 'Movie',
            streamUrl: 'https://example.invalid/movie.mp4',
            channelType: 'vod',
            streamId: 'movie-1',
          ),
          ParsedChannel(
            name: 'Series',
            streamUrl: 'https://example.invalid/series',
            channelType: 'series',
            streamId: 'series-1',
          ),
          ParsedChannel(
            name: 'Live',
            streamUrl: 'https://example.invalid/live.m3u8',
            channelType: 'live',
            streamId: 'live-1',
          ),
        ],
      );

      final initial = await db.select(db.channels).get();
      for (final channel in initial.where(
        (channel) => channel.channelType != 'live',
      )) {
        expect(await repository.toggleChannelWatchLater(channel.id), isTrue);
      }

      final later = await repository
          .watchWatchLaterByPlaylist(playlistId)
          .first;
      expect(
        later.map((channel) => channel.channelType),
        containsAll(<String>['vod', 'series']),
      );
      expect(later, hasLength(2));

      await repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: const [
          ParsedChannel(
            name: 'Renamed Movie',
            streamUrl: 'https://new.invalid/movie.mp4',
            channelType: 'vod',
            streamId: 'movie-1',
          ),
          ParsedChannel(
            name: 'Renamed Series',
            streamUrl: 'https://new.invalid/series',
            channelType: 'series',
            streamId: 'series-1',
          ),
        ],
      );

      final synced = await db.select(db.channels).get();
      expect(
        synced,
        everyElement(
          predicate<Channel>((channel) {
            return channel.isWatchLater;
          }),
        ),
      );
    },
  );
}
