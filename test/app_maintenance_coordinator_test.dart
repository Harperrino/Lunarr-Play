import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/services/app_maintenance_coordinator.dart';

void main() {
  test('waits for the latest idle window and serializes tasks', () async {
    var now = DateTime(2026);
    final waits = <Duration>[];
    final order = <int>[];
    final coordinator = AppMaintenanceCoordinator(
      now: () => now,
      delay: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
    );
    addTearDown(coordinator.dispose);

    coordinator.deferFor(const Duration(milliseconds: 250));
    final first = coordinator.schedule(() async => order.add(1));
    final second = coordinator.schedule(() async => order.add(2));
    await Future.wait([first, second]);

    expect(waits, [const Duration(milliseconds: 250)]);
    expect(order, [1, 2]);
  });

  test(
    'deduplicates pending keys and an error never poisons the queue',
    () async {
      final coordinator = AppMaintenanceCoordinator();
      addTearDown(coordinator.dispose);
      final blocker = Completer<void>();
      var duplicateRuns = 0;
      final first = coordinator.schedule(() async {
        duplicateRuns++;
        await blocker.future;
      }, key: 'same');
      await coordinator.schedule(() async => duplicateRuns++, key: 'same');
      blocker.complete();
      await first;
      expect(duplicateRuns, 1);

      await expectLater(
        coordinator.schedule(() async => throw StateError('failed')),
        throwsStateError,
      );
      var recovered = false;
      await coordinator.schedule(() async => recovered = true);
      expect(recovered, isTrue);
    },
  );

  test(
    'a running task observes newer deferrals at safe yield points',
    () async {
      var now = DateTime(2026);
      final waits = <Duration>[];
      final order = <String>[];
      final coordinator = AppMaintenanceCoordinator(
        now: () => now,
        delay: (duration) async {
          waits.add(duration);
          now = now.add(duration);
        },
      );
      addTearDown(coordinator.dispose);

      await coordinator.schedule(() async {
        order.add('playlist-1');
        coordinator.deferFor(const Duration(milliseconds: 250));
        await coordinator.waitUntilIdle();
        order.add('playlist-2');
      });

      expect(waits, [const Duration(milliseconds: 250)]);
      expect(order, ['playlist-1', 'playlist-2']);
    },
  );
}
