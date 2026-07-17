import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/favorites/providers/favorite_channels_providers.dart';

const _liveFavorite = Channel(
  id: 1,
  playlistId: 1,
  name: 'Lieblingssender',
  groupName: 'Nachrichten',
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: true,
  isWatchLater: false,
  channelType: 'live',
);

void main() {
  test('favorite derivation keeps only favourited live channels', () {
    const otherLive = Channel(
      id: 2,
      playlistId: 1,
      name: 'Nicht markiert',
      streamUrl: 'https://example.invalid/other.m3u8',
      isFavorite: false,
      isWatchLater: false,
      channelType: 'live',
    );
    const movieFavorite = Channel(
      id: 3,
      playlistId: 1,
      name: 'Film',
      streamUrl: 'https://example.invalid/movie.mp4',
      isFavorite: true,
      isWatchLater: false,
      channelType: 'vod',
    );
    const seriesFavorite = Channel(
      id: 4,
      playlistId: 1,
      name: 'Serie',
      streamUrl: 'https://example.invalid/series',
      isFavorite: true,
      isWatchLater: false,
      channelType: 'series',
    );

    expect(
      filterFavoriteLiveChannels([
        _liveFavorite,
        otherLive,
        movieFavorite,
        seriesFavorite,
      ]),
      [_liveFavorite],
    );
  });
}
