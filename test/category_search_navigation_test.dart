import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/services/category_search_navigation.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

import 'support/fake_media_player.dart';

class _RecordingPlayerNotifier extends FixedPlayerNotifier {
  _RecordingPlayerNotifier(super.initialState);

  int openCount = 0;
  String? lastUrl;

  @override
  Future<void> openStream(
    String url, {
    Duration? startPosition,
    bool startPaused = false,
    bool preBuffer = false,
  }) async {
    openCount++;
    lastUrl = url;
  }
}

ChannelSearchResult _searchResult() {
  return ChannelSearchResult(
    entry: const SearchCatalogEntry(
      channelId: 1,
      playlistId: 2,
      type: 'live',
      name: 'Foreign News',
      category: 'News',
    ),
    playlistId: 2,
    playlistName: 'Foreign playlist',
    categoryName: 'News',
  );
}

void main() {
  test(
    'openChannel selects the foreign playlist and opens one stream',
    () async {
      final player = _RecordingPlayerNotifier(
        PlayerState(player: FakeMediaPlayer(), isPlaying: false, volume: 0.8),
      );
      final database = AppDatabase.executor(NativeDatabase.memory());
      final repository = PlaylistRepository(database);
      await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'First playlist',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/first.m3u',
        ),
      );
      await repository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Foreign playlist',
          type: 'm3u',
          urlOrHost: 'https://example.invalid/foreign.m3u',
        ),
      );
      await repository.syncM3uChannels(
        playlistId: 2,
        parsedChannels: const [
          ParsedChannel(
            name: 'Foreign News',
            streamUrl: 'https://example.invalid/foreign.m3u8',
            groupName: 'News',
            channelType: 'live',
            providerOrder: 4,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          playerNotifierProvider.overrideWith(() => player),
          playlistRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final navigation = container.read(
        categorySearchNavigationControllerProvider,
      );
      await navigation.openChannel(_searchResult());

      expect(player.openCount, 1);
      expect(player.lastUrl, 'https://example.invalid/foreign.m3u8');
      expect(container.read(selectedPlaylistIdProvider), 2);
      expect(container.read(selectedGroupFilterProvider), 'News');
      expect(container.read(selectedChannelProvider)?.id, 1);
      expect(container.read(activeSidebarIndexProvider), shellLiveTabIndex);
    },
  );
}
