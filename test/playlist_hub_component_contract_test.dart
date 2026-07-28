import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/app/widgets/playlist_hub_screen.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/managed_playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';

void main() {
  testWidgets('active Playlist Hub keeps narrow row actions accessible', (
    tester,
  ) async {
    final container = await _pumpHub(
      tester,
      jobs: const <int, EpgSyncJob>{},
      width: 520,
    );

    expect(find.byType(Switch), findsOneWidget);
    expect(find.byTooltip('Sync playlist'), findsOneWidget);
    expect(find.byTooltip('More playlist actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _disposeHub(tester);
    container.dispose();
    await tester.pump();
  });

  testWidgets('active Playlist Hub distinguishes queued and failed EPG jobs', (
    tester,
  ) async {
    final requestedAt = DateTime.utc(2026, 7, 26);
    final queuedContainer = await _pumpHub(
      tester,
      jobs: <int, EpgSyncJob>{
        1: EpgSyncJob(
          playlistId: 1,
          status: EpgSyncStatus.queued,
          origin: EpgSyncOrigin.manual,
          requestedAt: requestedAt,
        ),
      },
    );
    expect(find.text('EPG syncing…'), findsOneWidget);

    final failedContainer = await _pumpHub(
      tester,
      jobs: <int, EpgSyncJob>{
        1: EpgSyncJob(
          playlistId: 1,
          status: EpgSyncStatus.failed,
          origin: EpgSyncOrigin.manual,
          requestedAt: requestedAt,
          completedAt: requestedAt,
          error: StateError('offline'),
        ),
      },
    );
    queuedContainer.dispose();
    await tester.pump();
    expect(find.text('EPG error'), findsOneWidget);

    await tester.tap(find.byTooltip('More playlist actions'));
    await tester.pumpAndSettle();
    expect(find.text('Retry EPG'), findsOneWidget);
    final retry = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Retry EPG'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(retry.enabled, isTrue);
    await _disposeHub(tester);
    failedContainer.dispose();
    await tester.pump();
  });
}

Future<void> _disposeHub(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

Future<ProviderContainer> _pumpHub(
  WidgetTester tester, {
  required Map<int, EpgSyncJob> jobs,
  double width = 900,
}) async {
  final container = ProviderContainer(
    overrides: [
      playlistsStreamProvider.overrideWith(
        (ref) => Stream.value(<Playlist>[_playlist]),
      ),
      managedPlaylistChannelsProvider.overrideWith(
        (ref, playlistId) => Stream.value(const <Channel>[]),
      ),
      managedHiddenGroupsProvider.overrideWith(
        (ref, playlistId) => Future.value(const <String>{}),
      ),
      managedPinnedGroupsProvider.overrideWith(
        (ref, playlistId) => Future.value(const <String>[]),
      ),
      epgSyncJobsProvider.overrideWith((ref) => Stream.value(jobs)),
      epgRefreshIntervalProvider.overrideWith(
        (ref, playlistId) => EpgRefreshIntervalNotifier.test(playlistId),
      ),
      playlistSyncStatusProvider.overrideWith(
        (ref, playlistId) => const AsyncData<void>(null),
      ),
      inactivePlaylistIdsProvider.overrideWith(
        _EmptyInactivePlaylistIdsNotifier.new,
      ),
      hiddenGroupsProvider.overrideWith(_EmptyHiddenGroupsNotifier.new),
      pinnedGroupsProvider.overrideWith(_EmptyPinnedGroupsNotifier.new),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 720,
            child: const PlaylistHubScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
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
  name: 'Test playlist',
  type: 'm3u',
  urlOrHost: 'https://example.invalid/list.m3u',
  epgUrl: 'https://example.invalid/guide.xml',
  createdAt: DateTime.utc(2026, 7, 26),
);
