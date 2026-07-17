import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_list_panel.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_section.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_detail_screen.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  testWidgets('EPG grid shimmer respects reduced motion', (tester) async {
    await _pumpEpg(tester, disableAnimations: true);

    expect(_shimmer(tester).enabled, isFalse);
  });

  testWidgets('EPG grid shimmer animates when motion is enabled', (
    tester,
  ) async {
    await _pumpEpg(tester, disableAnimations: false);

    expect(_shimmer(tester).enabled, isTrue);
  });

  testWidgets('channel loading shimmer respects reduced motion', (
    tester,
  ) async {
    final channels = StreamController<List<Channel>>();
    addTearDown(channels.close);

    await _pumpChannelList(
      tester,
      disableAnimations: true,
      channelsStream: channels.stream,
    );

    expect(_shimmer(tester).enabled, isFalse);
  });

  testWidgets('channel loading shimmer animates when motion is enabled', (
    tester,
  ) async {
    final channels = StreamController<List<Channel>>();
    addTearDown(channels.close);

    await _pumpChannelList(
      tester,
      disableAnimations: false,
      channelsStream: channels.stream,
    );

    expect(_shimmer(tester).enabled, isTrue);
  });

  testWidgets('channel sync uses a built-in loading state', (tester) async {
    await _pumpChannelList(
      tester,
      disableAnimations: true,
      channelsStream: Stream.value(const <Channel>[]),
      syncLoading: true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('channel sync remains stable when motion is enabled', (
    tester,
  ) async {
    await _pumpChannelList(
      tester,
      disableAnimations: false,
      channelsStream: Stream.value(const <Channel>[]),
      syncLoading: true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings sync shimmer respects reduced motion', (tester) async {
    await _pumpSettingsPlaylist(tester, disableAnimations: true);

    expect(_shimmer(tester).enabled, isFalse);
  });

  testWidgets('settings sync shimmer animates when motion is enabled', (
    tester,
  ) async {
    await _pumpSettingsPlaylist(tester, disableAnimations: false);

    expect(_shimmer(tester).enabled, isTrue);
  });

  testWidgets('series episode shimmer respects reduced motion', (tester) async {
    await _pumpSeriesDetail(tester, disableAnimations: true);

    expect(_shimmer(tester).enabled, isFalse);
  });

  testWidgets('series episode shimmer animates when motion is enabled', (
    tester,
  ) async {
    await _pumpSeriesDetail(tester, disableAnimations: false);

    expect(_shimmer(tester).enabled, isTrue);
  });
}

Shimmer _shimmer(WidgetTester tester) {
  final matches = find.byType(Shimmer);
  expect(matches, findsOneWidget);
  return tester.widget<Shimmer>(matches);
}

Future<void> _pumpEpg(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  final knownIds = StreamController<Set<String>>();
  addTearDown(knownIds.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith(
          (ref) =>
              throw StateError('EPG shimmer test must not open the database'),
        ),
        selectedPlaylistIdProvider.overrideWith((ref) => 1),
        playlistsStreamProvider.overrideWith(
          (ref) => Stream.value(<Playlist>[_playlist]),
        ),
        liveChannelsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Channel>[_liveChannel]),
        ),
        epgSyncNotifierProvider.overrideWith(_ReadyEpgSyncNotifier.new),
        knownEpgChannelIdsProvider.overrideWith((ref) => knownIds.stream),
        epgGridEntriesStreamProvider.overrideWith(
          (ref) => Stream.value(const <EpgEntry>[]),
        ),
        epgGridChannelsProvider.overrideWith(
          (ref) => const <Channel>[_liveChannel],
        ),
        epgGridRowsProvider.overrideWith(
          (ref) => const <EpgGridRowData>[
            EpgGridRowData(
              channel: _liveChannel,
              matchStatus: EpgMatchStatus.noTvgId,
              resolvedEpgChannelId: null,
              programs: <EpgEntry>[],
            ),
          ],
        ),
      ],
      child: _motionHost(
        disableAnimations: disableAnimations,
        child: const SizedBox(width: 900, height: 600, child: EpgScreen()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpChannelList(
  WidgetTester tester, {
  required bool disableAnimations,
  required Stream<List<Channel>> channelsStream,
  bool syncLoading = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError(
            'Channel shimmer test must not open the database',
          ),
        ),
        selectedPlaylistIdProvider.overrideWith(
          (ref) => syncLoading ? 1 : null,
        ),
        playlistsStreamProvider.overrideWith(
          (ref) => Stream.value(
            syncLoading ? <Playlist>[_playlist] : const <Playlist>[],
          ),
        ),
        liveChannelsStreamProvider.overrideWith((ref) => channelsStream),
        hiddenGroupsProvider.overrideWith(_EmptyHiddenGroupsNotifier.new),
        channelFavoriteControllerProvider.overrideWith(
          (ref) => ChannelFavoriteController((channelId) async => true),
        ),
        inactivePlaylistIdsProvider.overrideWith(
          _EmptyInactivePlaylistIdsNotifier.new,
        ),
        playlistSyncNotifierProvider.overrideWith(
          syncLoading
              ? _LoadingPlaylistSyncNotifier.new
              : _ReadyPlaylistSyncNotifier.new,
        ),
        epgSyncNotifierProvider.overrideWith(_ReadyEpgSyncNotifier.new),
      ],
      child: _motionHost(
        disableAnimations: disableAnimations,
        child: const SizedBox(
          width: 700,
          height: 600,
          child: ChannelListPanel(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpSettingsPlaylist(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  await tester.pumpWidget(
    _motionHost(
      disableAnimations: disableAnimations,
      child: SizedBox(
        width: 640,
        height: 500,
        child: SettingsPlaylistSection(
          items: const <SettingsPlaylistItem>[_settingsItem],
          isLoading: false,
          errorMessage: null,
          isSyncing: true,
          isEpgSyncing: false,
          isBusy: true,
          compact: false,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpSeriesDetail(
  WidgetTester tester, {
  required bool disableAnimations,
}) async {
  final episodes = Completer<List<ParsedSeriesEpisode>>();
  addTearDown(() {
    if (!episodes.isCompleted) {
      episodes.complete(const <ParsedSeriesEpisode>[]);
    }
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError(
            'Series shimmer test must not open the database',
          ),
        ),
        selectedPlaylistIdProvider.overrideWith((ref) => 1),
        seriesEpisodesProvider.overrideWith(
          (ref, channelDbId) => episodes.future,
        ),
        seriesResumeProvider.overrideWith(
          (ref, channelDbId) => Future.value(null),
        ),
      ],
      child: _motionHost(
        disableAnimations: disableAnimations,
        child: SizedBox(
          width: 800,
          height: 600,
          child: SeriesDetailScreen(
            seriesChannel: _seriesChannel,
            onBack: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _motionHost({required bool disableAnimations, required Widget child}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
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

class _LoadingPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() => Completer<void>().future;
}

class _EmptyHiddenGroupsNotifier extends HiddenGroupsNotifier {
  @override
  Future<Set<String>> build() async => const <String>{};
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

const _liveChannel = Channel(
  id: 1,
  playlistId: 1,
  streamId: null,
  name: 'Test channel',
  logo: null,
  groupName: 'Tests',
  tvgId: null,
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'live',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);

const _seriesChannel = Channel(
  id: 2,
  playlistId: 1,
  streamId: 'series-2',
  name: 'Test series',
  logo: null,
  groupName: 'Tests',
  tvgId: null,
  streamUrl: 'https://example.invalid/series',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'series',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);

const _settingsItem = SettingsPlaylistItem(
  name: 'Test playlist',
  type: 'm3u',
  isActive: true,
  lastSyncedAt: null,
  epgUrl: null,
  epgLastSyncedAt: null,
  onSync: _noop,
  onEpgSync: _noop,
  onEdit: _noop,
  onActiveChanged: _ignoreBool,
  onDelete: _noop,
);

void _noop() {}

void _ignoreBool(bool value) {}
