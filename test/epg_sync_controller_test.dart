import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/core/services/epg_auto_refresh_coordinator.dart';
import 'package:m3uxtream_player/core/services/epg_sync_controller.dart';

void main() {
  test(
    'deduplicates one playlist and serializes different playlists',
    () async {
      final firstRelease = Completer<void>();
      final calls = <int>[];
      final controller = EpgSyncController(
        sync: (playlistId) {
          calls.add(playlistId);
          return playlistId == 1 ? firstRelease.future : Future<void>.value();
        },
      );
      final events = <EpgSyncJob>[];
      final subscription = controller.watchEvents().listen(events.add);

      final first = controller.enqueue(1);
      final duplicate = controller.enqueue(1);
      final second = controller.enqueue(2);

      expect(identical(first, duplicate), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(calls, [1]);
      expect(controller.jobFor(1)?.status, EpgSyncStatus.syncing);
      expect(controller.jobFor(2)?.status, EpgSyncStatus.queued);

      firstRelease.complete();
      await first;
      await second;

      expect(calls, [1, 2]);
      expect(controller.jobFor(1)?.status, EpgSyncStatus.succeeded);
      expect(controller.jobFor(2)?.status, EpgSyncStatus.succeeded);
      expect(
        events.where((job) => job.playlistId == 1).map((job) => job.status),
        [EpgSyncStatus.queued, EpgSyncStatus.syncing, EpgSyncStatus.succeeded],
      );

      await subscription.cancel();
      await controller.dispose();
    },
  );

  test('a failed job does not stop the next playlist', () async {
    final controller = EpgSyncController(
      sync: (playlistId) async {
        if (playlistId == 1) throw StateError('broken guide');
      },
    );
    final first = controller.enqueue(1);
    final second = controller.enqueue(2);

    await expectLater(first, throwsA(isA<StateError>()));
    await second;

    expect(controller.jobFor(1)?.status, EpgSyncStatus.failed);
    expect(controller.jobFor(2)?.status, EpgSyncStatus.succeeded);
    await controller.dispose();
  });

  test('automatic coordinator only refreshes due active playlists', () async {
    final now = DateTime(2026, 7, 20, 12);
    final calls = <int>[];
    final controller = EpgSyncController(
      now: () => now,
      sync: (playlistId) async => calls.add(playlistId),
    );
    final playlists = [
      _playlist(
        id: 1,
        epgUrl: 'https://example.invalid/one.xml',
        epgLastSyncedAt: now.subtract(const Duration(hours: 7)),
      ),
      _playlist(
        id: 2,
        epgUrl: 'https://example.invalid/two.xml',
        epgLastSyncedAt: now.subtract(const Duration(hours: 7)),
      ),
      _playlist(
        id: 3,
        epgUrl: 'https://example.invalid/three.xml',
        epgLastSyncedAt: now.subtract(const Duration(hours: 7)),
      ),
      _playlist(id: 4, epgLastSyncedAt: now.subtract(const Duration(hours: 7))),
    ];
    final intervals = <int, EpgRefreshInterval>{
      1: EpgRefreshInterval.hours6,
      2: EpgRefreshInterval.manual,
      3: EpgRefreshInterval.hours6,
      4: EpgRefreshInterval.hours6,
    };
    final timers = <Timer>[];
    final coordinator = EpgAutoRefreshCoordinator(
      controller: controller,
      now: () => now,
      loadPlaylists: () async => playlists,
      loadInactivePlaylistIds: () async => {3},
      loadInterval: (playlistId) async => intervals[playlistId]!,
      timerFactory: (duration, callback) {
        final timer = Timer(duration, callback);
        timers.add(timer);
        return timer;
      },
    );

    await coordinator.checkNow();
    await Future<void>.delayed(Duration.zero);

    expect(calls, [1]);
    expect(controller.jobFor(1)?.status, EpgSyncStatus.succeeded);
    expect(timers, isEmpty);

    await coordinator.dispose();
    await controller.dispose();
  });

  test('automatic failures use 15 minute retry backoff', () async {
    final now = DateTime(2026, 7, 20, 12);
    final playlist = _playlist(
      id: 1,
      epgUrl: 'https://example.invalid/one.xml',
      epgLastSyncedAt: now.subtract(const Duration(days: 2)),
    );
    final scheduled = <Duration>[];
    final controller = EpgSyncController(
      now: () => now,
      sync: (_) async => throw StateError('offline'),
    );
    final failed = Completer<void>();
    final subscription = controller.watchEvents().listen((job) {
      if (job.status == EpgSyncStatus.failed && !failed.isCompleted) {
        failed.complete();
      }
    });
    final coordinator = EpgAutoRefreshCoordinator(
      controller: controller,
      now: () => now,
      loadPlaylists: () async => [playlist],
      loadInactivePlaylistIds: () async => <int>{},
      loadInterval: (_) async => EpgRefreshInterval.hours6,
      timerFactory: (duration, callback) {
        scheduled.add(duration);
        return Timer(const Duration(days: 1), callback);
      },
    );

    coordinator.start();
    await failed.future;
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.retryAtFor(1), now.add(const Duration(minutes: 15)));
    expect(scheduled, contains(const Duration(minutes: 15)));

    await subscription.cancel();
    await coordinator.dispose();
    await controller.dispose();
  });
}

Playlist _playlist({
  required int id,
  String? epgUrl,
  DateTime? epgLastSyncedAt,
}) {
  return Playlist(
    id: id,
    name: 'Playlist $id',
    type: 'm3u',
    urlOrHost: 'https://example.invalid/$id.m3u',
    createdAt: DateTime(2026, 1, 1),
    epgUrl: epgUrl,
    epgLastSyncedAt: epgLastSyncedAt,
  );
}
