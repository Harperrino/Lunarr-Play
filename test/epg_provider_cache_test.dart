import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';

Channel _channel({int id = 1, String name = 'RTL HD', String? tvgId}) {
  return Channel(
    id: id,
    playlistId: 1,
    streamId: null,
    name: name,
    logo: null,
    groupName: 'German TV',
    tvgId: tvgId,
    streamUrl: 'http://example.com/stream.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
    lastWatchedPosition: null,
    duration: null,
    lastWatchedAt: null,
  );
}

void main() {
  test(
    'epg providers stay warm briefly and dispose after the warm-cache window',
    () async {
      final container = ProviderContainer(
        overrides: [
          epgWarmCacheDurationProvider.overrideWith((ref) {
            return const Duration(milliseconds: 40);
          }),
          selectedPlaylistIdProvider.overrideWith((ref) => 1),
          knownEpgChannelIdsProvider.overrideWith((ref) {
            return Stream.value(const {'de.rtl'});
          }),
          epgChannelDisplayNamesProvider.overrideWith((ref) {
            return Stream.value(const {
              'de.rtl': ['RTL HD'],
            });
          }),
          liveChannelsStreamProvider.overrideWith((ref) {
            return Stream.value([
              _channel(id: 1, name: 'DE: RTL HD', tvgId: null),
              _channel(id: 2, name: 'DE: RTL HD', tvgId: null),
            ]);
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(knownEpgChannelIdsProvider.future);
      await container.read(epgChannelDisplayNamesProvider.future);
      await container.read(liveChannelsStreamProvider.future);

      final indexSubA = container.listen<EpgMatchingIndex>(
        epgMatchingIndexProvider,
        (_, _) {},
      );
      final matchesSubA = container.listen<Map<int, EpgChannelMatchResult>>(
        epgChannelMatchesProvider,
        (_, _) {},
      );
      final indexA = indexSubA.read();
      final matchesA = matchesSubA.read();
      expect(indexA.memoizedMatchCount, 1);

      indexSubA.close();
      matchesSubA.close();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final indexSubB = container.listen<EpgMatchingIndex>(
        epgMatchingIndexProvider,
        (_, _) {},
      );
      final matchesSubB = container.listen<Map<int, EpgChannelMatchResult>>(
        epgChannelMatchesProvider,
        (_, _) {},
      );
      final indexB = indexSubB.read();
      final matchesB = matchesSubB.read();

      expect(identical(indexA, indexB), isTrue);
      expect(identical(matchesA, matchesB), isTrue);

      indexSubB.close();
      matchesSubB.close();

      await Future<void>.delayed(const Duration(milliseconds: 200));
      await Future<void>.delayed(Duration.zero);

      final indexSubC = container.listen<EpgMatchingIndex>(
        epgMatchingIndexProvider,
        (_, _) {},
      );
      final matchesSubC = container.listen<Map<int, EpgChannelMatchResult>>(
        epgChannelMatchesProvider,
        (_, _) {},
      );
      await container.read(knownEpgChannelIdsProvider.future);
      await container.read(epgChannelDisplayNamesProvider.future);
      await container.read(liveChannelsStreamProvider.future);
      await Future<void>.delayed(Duration.zero);
      final indexC = indexSubC.read();
      final matchesC = matchesSubC.read();

      expect(identical(indexA, indexC), isFalse);
      expect(identical(matchesA, matchesC), isFalse);
      expect(matchesC[1]?.resolvedEpgChannelId, 'de.rtl');
      expect(indexC.memoizedMatchCount, 1);

      indexSubC.close();
      matchesSubC.close();
    },
  );

  test(
    'search filtering does not invalidate the EPG matching catalogue',
    () async {
      final container = ProviderContainer(
        overrides: [
          knownEpgChannelIdsProvider.overrideWith(
            (ref) => Stream.value(const {'de.rtl'}),
          ),
          epgChannelDisplayNamesProvider.overrideWith(
            (ref) => Stream.value(const {
              'de.rtl': ['RTL HD'],
            }),
          ),
          liveChannelsStreamProvider.overrideWith(
            (ref) => Stream.value([
              _channel(id: 1, name: 'DE: RTL HD'),
              _channel(id: 2, name: 'Another channel'),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final matchesSub = container.listen<Map<int, EpgChannelMatchResult>>(
        epgChannelMatchesProvider,
        (_, _) {},
      );
      addTearDown(matchesSub.close);

      await container.read(knownEpgChannelIdsProvider.future);
      await container.read(epgChannelDisplayNamesProvider.future);
      await container.read(liveChannelsStreamProvider.future);
      await Future<void>.delayed(Duration.zero);

      final matchesBeforeSearch = matchesSub.read();
      expect(matchesBeforeSearch.keys, containsAll(<int>[1, 2]));

      container.read(globalSearchQueryProvider.notifier).state = 'rtl';
      await Future<void>.delayed(Duration.zero);

      expect(identical(matchesBeforeSearch, matchesSub.read()), isTrue);
    },
  );
}
