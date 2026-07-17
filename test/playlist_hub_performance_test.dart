import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_hub_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/widgets/playlist_hub_screen.dart';

void main() {
  test(
    'PlaylistHub view data filters and partitions categories in one pass',
    () {
      final channels = [
        _channel(1, 'News', 'live'),
        _channel(2, 'Sports', 'live'),
        _channel(3, 'Movies', 'vod'),
        _channel(4, 'News', 'vod'),
      ];

      final data = buildPlaylistHubCategoryViewData(
        channels: channels,
        contentFilter: PlaylistContentFilter.live,
        hiddenGroups: {'Sports'},
        pinnedGroups: ['Sports', 'News'],
      );

      expect(data.allGroups, ['News', 'Sports']);
      expect(data.visibleGroups, ['News']);
      expect(data.hiddenGroups, ['Sports']);
      expect(data.matchingChannelCount, 2);
      expect(data.pinnedVisibleCount, 1);
      expect(data.pinnedHiddenCount, 1);
    },
  );

  testWidgets('PlaylistHub lazily builds a large category catalogue', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final channels = List<Channel>.generate(
      300,
      (index) => Channel(
        id: index + 1,
        playlistId: 1,
        name: 'Channel $index',
        streamUrl: 'https://example.invalid/$index.m3u8',
        isFavorite: false,
        isWatchLater: false,
        channelType: 'live',
        groupName: 'Category ${index.toString().padLeft(3, '0')}',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        playlistsStreamProvider.overrideWith(
          (ref) => Stream.value(<Playlist>[_playlist]),
        ),
        channelsStreamProvider.overrideWith((ref) => Stream.value(channels)),
        inactivePlaylistIdsProvider.overrideWith(
          _EmptyInactivePlaylistIdsNotifier.new,
        ),
        hiddenGroupsProvider.overrideWith(_EmptyHiddenGroupsNotifier.new),
        pinnedGroupsProvider.overrideWith(_EmptyPinnedGroupsNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PlaylistHubScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    final builtSwitches = find.byType(Switch).evaluate().length;
    expect(builtSwitches, greaterThan(0));
    expect(builtSwitches, lessThan(50));
    expect(find.text('Category 299'), findsNothing);
  });
}

class _EmptyHiddenGroupsNotifier extends HiddenGroupsNotifier {
  @override
  Future<Set<String>> build() async => const <String>{};
}

class _EmptyPinnedGroupsNotifier extends PinnedGroupsNotifier {
  @override
  Future<List<String>> build() async => const <String>[];
}

class _EmptyInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

final _playlist = Playlist(
  id: 1,
  name: 'Performance test playlist',
  type: 'm3u',
  urlOrHost: 'https://example.invalid/list.m3u',
  createdAt: DateTime(2026, 7, 17),
);

Channel _channel(int id, String groupName, String channelType) {
  return Channel(
    id: id,
    playlistId: 1,
    name: 'Channel $id',
    streamUrl: 'https://example.invalid/$id.m3u8',
    isFavorite: false,
    isWatchLater: false,
    channelType: channelType,
    groupName: groupName,
  );
}
