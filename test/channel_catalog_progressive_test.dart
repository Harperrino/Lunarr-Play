import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_sort_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_list_panel.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'cached rows survive catalogue loading and a refresh error while EPG waits',
    (tester) async {
      final channels = StreamController<List<Channel>>.broadcast();
      addTearDown(channels.close);
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          selectedPlaylistIdProvider.overrideWith((ref) => 1),
          playlistsStreamProvider.overrideWith(
            (ref) => Stream.value(<Playlist>[_playlist]),
          ),
          inactivePlaylistIdsProvider.overrideWith(
            _EmptyInactivePlaylistIdsNotifier.new,
          ),
          hiddenGroupsForPlaylistProvider(
            1,
          ).overrideWith((ref) async => const <String>{}),
          liveChannelsStreamProvider.overrideWith((ref) => channels.stream),
          channelSortModeProvider(
            1,
          ).overrideWith((ref) => ChannelSortModeNotifier.test(1)),
          playlistSyncNotifierProvider.overrideWith(
            _ReadyPlaylistSyncNotifier.new,
          ),
          epgSyncNotifierProvider.overrideWith(_ReadyEpgSyncNotifier.new),
          channelFavoriteControllerProvider.overrideWith(
            (ref) => ChannelFavoriteController((channelId) async => true),
          ),
          visibleLiveEpgMatchesProvider.overrideWith(
            (ref) =>
                const AsyncValue<Map<int, EpgChannelMatchResult>>.loading(),
          ),
          currentProgramsForVisibleChannelsProvider.overrideWith(
            (ref) => const Stream<Map<int, EpgEntry?>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SizedBox(
                width: 700,
                height: 600,
                child: ChannelListPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      channels.add(const <Channel>[_channel]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Test channel'), findsOneWidget);
      expect(find.text('EPG wird geladen…'), findsOneWidget);

      // A scope/query refresh has no first value yet. The last valid row must
      // remain mounted instead of being replaced by the shimmer.
      container.invalidate(liveChannelsStreamProvider);
      await tester.pump();
      await tester.pump();
      expect(find.text('Test channel'), findsOneWidget);

      channels.addError(StateError('refresh failed'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Test channel'), findsOneWidget);
      expect(
        find.textContaining('Die zuletzt geladenen Sender bleiben sichtbar'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}

class _ReadyEpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

class _ReadyPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _EmptyInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

final _playlist = Playlist(
  id: 1,
  name: 'Test playlist',
  type: 'm3u',
  urlOrHost: 'https://example.invalid/list.m3u',
  createdAt: DateTime(2026, 7, 1),
);

const _channel = Channel(
  providerOrder: 1,
  id: 1,
  playlistId: 1,
  streamId: null,
  name: 'Test channel',
  logo: null,
  groupName: 'Tests',
  tvgId: 'test.epg',
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'live',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);
