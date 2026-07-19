import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
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
  final channel = Channel(
    id: 77,
    playlistId: 2,
    name: 'Foreign News',
    streamUrl: 'https://example.invalid/foreign.m3u8',
    providerOrder: 4,
    groupName: 'News',
    isFavorite: false,
    isWatchLater: false,
    channelType: 'live',
  );
  return ChannelSearchResult(
    channel: channel,
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
      final container = ProviderContainer(
        overrides: [playerNotifierProvider.overrideWith(() => player)],
      );
      addTearDown(container.dispose);

      final navigation = container.read(
        categorySearchNavigationControllerProvider,
      );
      await navigation.openChannel(_searchResult());

      expect(player.openCount, 1);
      expect(player.lastUrl, 'https://example.invalid/foreign.m3u8');
      expect(container.read(selectedPlaylistIdProvider), 2);
      expect(container.read(selectedGroupFilterProvider), 'News');
      expect(container.read(selectedChannelProvider)?.id, 77);
      expect(container.read(activeSidebarIndexProvider), shellLiveTabIndex);
    },
  );
}
