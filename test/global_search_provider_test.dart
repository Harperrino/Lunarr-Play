import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';
import 'package:m3uxtream_player/app/composition/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

Future<
  ({AppDatabase database, ProviderContainer container, int activePlaylistId})
>
_buildSearchFixture() async {
  final database = AppDatabase.executor(NativeDatabase.memory());
  final repository = PlaylistRepository(database);
  final appState = AppStateRepository(database);
  final activePlaylistId = await repository.insertPlaylist(
    PlaylistsCompanion.insert(
      name: 'Active playlist',
      type: 'm3u',
      urlOrHost: 'https://example.invalid/active.m3u',
    ),
  );
  final inactivePlaylistId = await repository.insertPlaylist(
    PlaylistsCompanion.insert(
      name: 'Inactive playlist',
      type: 'm3u',
      urlOrHost: 'https://example.invalid/inactive.m3u',
    ),
  );

  await repository.syncM3uChannels(
    playlistId: activePlaylistId,
    parsedChannels: const [
      ParsedChannel(
        name: 'Visible News',
        streamUrl: 'https://example.invalid/visible',
        groupName: 'Sports',
        channelType: 'live',
        providerOrder: 0,
      ),
      ParsedChannel(
        name: 'Sports Channel',
        streamUrl: 'https://example.invalid/group-match-only',
        groupName: 'News',
        channelType: 'live',
        providerOrder: 1,
      ),
      ParsedChannel(
        name: 'Hidden News',
        streamUrl: 'https://example.invalid/hidden',
        groupName: 'Hidden',
        channelType: 'live',
        providerOrder: 2,
      ),
      ParsedChannel(
        name: 'News Movie',
        streamUrl: 'https://example.invalid/movie',
        groupName: 'Movies',
        channelType: 'vod',
        providerOrder: 3,
      ),
    ],
  );
  await repository.syncM3uChannels(
    playlistId: inactivePlaylistId,
    parsedChannels: const [
      ParsedChannel(
        name: 'Inactive News',
        streamUrl: 'https://example.invalid/inactive',
        groupName: 'Inactive',
        channelType: 'live',
        providerOrder: 0,
      ),
    ],
  );

  await appState.setPlaylistActive(inactivePlaylistId, false);
  await appState.setHiddenGroups(activePlaylistId, {'Hidden'});

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      playlistRepositoryProvider.overrideWithValue(repository),
      appStateRepositoryProvider.overrideWithValue(appState),
      epgMatchingIndexProvider.overrideWithValue(
        PlaylistEpgMatchingIndex(knownEpgChannelIdsByPlaylist: const {}),
      ),
    ],
  );
  container.read(selectedPlaylistIdProvider.notifier).state = activePlaylistId;
  await container.read(playlistsStreamProvider.future);
  await container.read(inactivePlaylistIdsProvider.future);
  await container.read(hiddenGroupsProvider.future);
  container.read(searchOverlaySessionProvider.notifier).state =
      const SearchOverlaySessionState(isOpen: true);
  await container.read(globalSearchChannelsStreamProvider.future);

  return (
    database: database,
    container: container,
    activePlaylistId: activePlaylistId,
  );
}

ChannelSearchResult _channelResult(int id) {
  return ChannelSearchResult(
    entry: SearchCatalogEntry(
      channelId: id,
      playlistId: 1,
      type: 'live',
      name: 'Channel $id',
    ),
    playlistId: 1,
    playlistName: 'Main',
    categoryName: 'News',
  );
}

void main() {
  test(
    'global search excludes inactive and hidden playlists/categories',
    () async {
      final fixture = await _buildSearchFixture();
      addTearDown(() async {
        fixture.container.dispose();
        await fixture.database.close();
      });

      fixture.container.read(globalSearchQueryProvider.notifier).state = 'news';
      await fixture.container.read(globalSearchResultsAsyncProvider.future);
      final channels = fixture.container.read(channelSearchResultsProvider);
      final categories = fixture.container.read(categorySearchResultsProvider);

      expect(channels.map((result) => result.entry.name), ['Visible News']);
      expect(categories.map((result) => result.categoryName), ['News']);
      expect(categories.single.playlistId, fixture.activePlaylistId);
    },
  );

  test('All tab fills missing slots with the other result type', () {
    final manyChannels = List<ChannelSearchResult>.generate(
      12,
      (index) => _channelResult(index + 1),
    );
    final categories = List<CategorySearchResult>.generate(
      12,
      (index) => CategorySearchResult(
        target: CategorySearchTarget.live,
        categoryName: 'Category $index',
        playlistId: 1,
        playlistName: 'Main',
        isPinned: false,
      ),
    );

    final initialMix = GlobalSearchResults(
      channels: manyChannels,
      categories: categories,
    ).itemsFor(SearchOverlayFilter.all);
    expect(initialMix.take(8).every((item) => item.isChannel), isTrue);
    expect(initialMix.skip(8).take(4).every((item) => !item.isChannel), isTrue);
    expect(initialMix, hasLength(12));

    final categoryFill = GlobalSearchResults(
      channels: manyChannels.take(3).toList(),
      categories: categories,
    ).itemsFor(SearchOverlayFilter.all);
    expect(categoryFill.take(3).every((item) => item.isChannel), isTrue);
    expect(categoryFill, hasLength(12));

    final channelFill = GlobalSearchResults(
      channels: manyChannels,
      categories: categories.take(2).toList(),
    ).itemsFor(SearchOverlayFilter.all);
    expect(channelFill, hasLength(12));
    expect(channelFill.where((item) => item.isChannel), hasLength(10));
    expect(channelFill.where((item) => !item.isChannel), hasLength(2));
  });
}
