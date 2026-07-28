import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';

void main() {
  test(
    'grid publishes one non-reactive snapshot and discards stale keys',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      final repository = _SnapshotEpgRepository(database);
      const scope = PlaylistCatalogScope.single(1);
      final container = ProviderContainer(
        overrides: [
          epgRepositoryProvider.overrideWithValue(repository),
          effectivePlaylistCatalogScopeProvider.overrideWithValue(scope),
          playlistCatalogPlaylistIdsProvider(
            scope,
          ).overrideWith((ref) => const [1]),
          knownEpgChannelIdsProvider.overrideWith(
            (ref) => Stream.value(const {
              1: {'shared.id'},
            }),
          ),
          epgGridResolvedChannelIdsProvider.overrideWithValue(const {
            1: {'shared.id'},
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(database.close);

      await container.read(knownEpgChannelIdsProvider.future);
      final emitted = <List<EpgEntry>>[];
      final subscription = container.listen<AsyncValue<List<EpgEntry>>>(
        epgGridEntriesSnapshotProvider,
        (_, next) {
          if (next.hasValue) emitted.add(next.requireValue);
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);

      expect(repository.requests, hasLength(1));
      expect(repository.watchCallCount, 0);

      final staleRequest = repository.requests.single;
      final shiftedStart = container
          .read(epgWindowStartProvider)
          .add(const Duration(hours: 1));
      container.read(epgWindowStartProvider.notifier).state = shiftedStart;
      await Future<void>.delayed(Duration.zero);
      expect(repository.requests, hasLength(2));

      staleRequest.completer.complete([_entry(id: 1, title: 'Stale')]);
      await Future<void>.delayed(Duration.zero);
      expect(
        emitted.expand((entries) => entries).map((entry) => entry.title),
        isNot(contains('Stale')),
      );

      final latestKey = container.read(epgGridSnapshotKeyProvider);
      final latestSnapshot = container.read(
        epgGridSnapshotProvider(latestKey).future,
      );
      repository.requests.last.completer.complete([
        _entry(id: 2, title: 'Current'),
      ]);
      await latestSnapshot;
      await Future<void>.delayed(Duration.zero);

      expect(repository.watchCallCount, 0);
      expect(emitted, hasLength(1));
      expect(emitted.single.single.title, 'Current');
    },
  );
}

class _SnapshotRequest {
  _SnapshotRequest({
    required this.channelIdsByPlaylist,
    required this.start,
    required this.end,
    required this.completer,
  });

  final Map<int, Set<String>> channelIdsByPlaylist;
  final DateTime start;
  final DateTime end;
  final Completer<List<EpgEntry>> completer;
}

class _SnapshotEpgRepository extends EpgRepository {
  _SnapshotEpgRepository(super.database);

  final requests = <_SnapshotRequest>[];
  int watchCallCount = 0;

  @override
  Future<List<EpgEntry>> getEntriesSnapshotForPlaylistChannelIds(
    Map<int, Set<String>> channelIdsByPlaylist,
    DateTime start,
    DateTime end,
  ) {
    final completer = Completer<List<EpgEntry>>();
    requests.add(
      _SnapshotRequest(
        channelIdsByPlaylist: channelIdsByPlaylist,
        start: start,
        end: end,
        completer: completer,
      ),
    );
    return completer.future;
  }

  @override
  Stream<List<EpgEntry>> watchEntriesInRangeForPlaylistChannelIds(
    Map<int, Set<String>> channelIdsByPlaylist,
    DateTime start,
    DateTime end,
  ) {
    watchCallCount++;
    return const Stream.empty();
  }
}

EpgEntry _entry({required int id, required String title}) {
  final start = DateTime(2026, 7, 26, 12);
  return EpgEntry(
    id: id,
    playlistId: 1,
    channelId: 'shared.id',
    title: title,
    description: null,
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
  );
}
