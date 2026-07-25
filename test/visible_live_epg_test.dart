import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/channels/widgets/visible_live_channel_row.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/visible_live_channel_registry.dart';

class _CountingEpgRepository extends EpgRepository {
  _CountingEpgRepository(super.database);

  final List<List<String>> queries = <List<String>>[];
  int cancelCount = 0;
  List<EpgEntry> entries = const <EpgEntry>[];

  @override
  Stream<List<EpgEntry>> watchEntriesInRangeForChannelIds(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) {
    queries.add(List<String>.of(channelIds));
    late StreamController<List<EpgEntry>> controller;
    controller = StreamController<List<EpgEntry>>(
      onListen: () => controller.add(entries),
      onCancel: () => cancelCount++,
    );
    return controller.stream;
  }
}

VisibleLiveChannelCandidate _candidate(int id, {String? name, String? tvgId}) =>
    VisibleLiveChannelCandidate(
      channelId: id,
      playlistId: 1,
      name: name ?? 'Channel $id',
      tvgId: tvgId ?? 'epg-$id',
    );

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition was not met in time');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VisibleLiveChannelRegistry', () {
    test('bundles mutations and never republishes identical sets', () async {
      final registry = VisibleLiveChannelRegistry(
        publishDelay: const Duration(milliseconds: 5),
      );
      addTearDown(registry.dispose);
      final emitted = <List<VisibleLiveChannelCandidate>>[];
      final subscription = registry.changes.listen(emitted.add);
      addTearDown(subscription.cancel);

      registry.register(_candidate(1));
      registry.register(_candidate(2));
      registry.register(_candidate(3));
      expect(emitted, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted.map((set) => set.map((c) => c.channelId).toList()), [
        [1, 2, 3],
      ]);

      // Re-registering identical projections keeps the set identical.
      registry.register(_candidate(3));
      registry.register(_candidate(1));
      registry.register(_candidate(2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted, hasLength(1));

      // A changed projection is a real change and republishes.
      registry.register(_candidate(2, name: 'Renamed channel'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted, hasLength(2));

      registry.unregister(2);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emitted, hasLength(3));
      expect(
        emitted.last.map((c) => c.channelId).toSet(),
        {1, 3},
      );
    });

    test('publishes at most 64 most recently visible candidates', () async {
      final registry = VisibleLiveChannelRegistry(
        publishDelay: const Duration(milliseconds: 5),
      );
      addTearDown(registry.dispose);
      final emitted = <List<VisibleLiveChannelCandidate>>[];
      final subscription = registry.changes.listen(emitted.add);
      addTearDown(subscription.cancel);

      for (var id = 1; id <= 100; id++) {
        registry.register(_candidate(id));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(emitted, hasLength(1));
      expect(emitted.single, hasLength(64));
      expect(emitted.single.first.channelId, 37);
      expect(emitted.single.last.channelId, 100);
    });
  });

  group('VisibleLiveChannelRow', () {
    Widget buildList(int itemCount) {
      return MaterialApp(
        home: SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: itemCount,
            itemExtent: 40,
            itemBuilder: (context, index) => VisibleLiveChannelRow(
              key: ValueKey(index + 1),
              candidate: _candidate(index + 1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    testWidgets('rows register on mount, replace the set on scroll and clear'
        ' on dispose', (tester) async {
      final registry = VisibleLiveChannelRegistry(
        publishDelay: const Duration(milliseconds: 10),
      );
      addTearDown(registry.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibleLiveChannelRegistryProvider.overrideWithValue(registry),
          ],
          child: buildList(100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final initial = registry.current.map((c) => c.channelId).toList();
      expect(initial, isNotEmpty);
      expect(initial.length, lessThanOrEqualTo(64));
      expect(initial.contains(1), isTrue);
      expect(initial.every((id) => id <= 40), isTrue);

      // Scrolling replaces the visible set completely.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final scrolled = registry.current.map((c) => c.channelId).toList();
      expect(scrolled, isNotEmpty);
      expect(scrolled.contains(1), isFalse);
      expect(scrolled, isNot(equals(initial)));

      // A catalogue switch unmounts every row and empties the set.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibleLiveChannelRegistryProvider.overrideWithValue(registry),
          ],
          child: buildList(0),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(registry.current, isEmpty);
    });
  });

  group('visible Live EPG pipeline', () {
    late AppDatabase database;
    late _CountingEpgRepository epgRepository;

    setUp(() {
      database = AppDatabase.executor(NativeDatabase.memory());
      epgRepository = _CountingEpgRepository(database);
    });

    tearDown(() => database.close());

    EpgMatchingIndex buildIndex(int count) => EpgMatchingIndex(
      knownEpgChannelIds: {for (var id = 1; id <= count; id++) 'epg-$id'},
    );

    ProviderContainer buildContainer({
      required Stream<List<VisibleLiveChannelCandidate>> Function() candidates,
      required EpgMatchingIndex index,
      bool inputsReady = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          epgRepositoryProvider.overrideWithValue(epgRepository),
          visibleLiveChannelCandidatesProvider.overrideWith(
            (ref) => candidates(),
          ),
          epgMatchingIndexProvider.overrideWithValue(index),
          epgMatchingInputsReadyProvider.overrideWith(
            (ref) => inputsReady,
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        currentProgramsForVisibleChannelsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);
      return container;
    }

    test('an empty visible set opens no SQL query', () async {
      final container = buildContainer(
        candidates: () =>
            Stream.value(const <VisibleLiveChannelCandidate>[]),
        index: buildIndex(4),
      );

      final map = await container.read(
        currentProgramsForVisibleChannelsProvider.future,
      );
      expect(map, isEmpty);
      expect(epgRepository.queries, isEmpty);
    });

    test('an unmatched visible set opens no SQL query', () async {
      final container = buildContainer(
        candidates: () => Stream.value([
          _candidate(1, tvgId: 'unknown-1'),
          _candidate(2, tvgId: 'unknown-2'),
        ]),
        index: buildIndex(4),
      );

      final map = await container.read(
        currentProgramsForVisibleChannelsProvider.future,
      );
      expect(map, {1: null, 2: null});
      expect(epgRepository.queries, isEmpty);
    });

    test('matching stays in a neutral loading state while inputs warm up', () async {
      final container = buildContainer(
        candidates: () => Stream.value([_candidate(1)]),
        index: buildIndex(4),
        inputsReady: false,
      );

      final matches = container.read(visibleLiveEpgMatchesProvider);
      expect(matches.isLoading, isTrue);
      expect(matches.hasValue, isFalse);
      expect(epgRepository.queries, isEmpty);
    });

    test('the Live tab never builds the global catalogue match map', () async {
      var globalMatchBuilds = 0;
      final container = ProviderContainer(
        overrides: [
          epgRepositoryProvider.overrideWithValue(epgRepository),
          visibleLiveChannelCandidatesProvider.overrideWith(
            (ref) => Stream.value([_candidate(1), _candidate(2)]),
          ),
          epgMatchingIndexProvider.overrideWithValue(buildIndex(4)),
          epgMatchingInputsReadyProvider.overrideWith((ref) => true),
          epgChannelMatchesProvider.overrideWith((ref) {
            globalMatchBuilds++;
            return const <int, EpgChannelMatchResult>{};
          }),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        currentProgramsForVisibleChannelsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);
      final matchesAlive = container.listen(
        visibleLiveEpgMatchesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(matchesAlive.close);

      await container.read(currentProgramsForVisibleChannelsProvider.future);

      expect(globalMatchBuilds, 0);
      expect(epgRepository.queries.single.toSet(), {'epg-1', 'epg-2'});
    });

    test('the registry bounds the bulk query to 64 rows end to end', () async {
      final registry = VisibleLiveChannelRegistry(
        publishDelay: const Duration(milliseconds: 5),
      );
      addTearDown(registry.dispose);
      final container = ProviderContainer(
        overrides: [
          epgRepositoryProvider.overrideWithValue(epgRepository),
          visibleLiveChannelRegistryProvider.overrideWithValue(registry),
          epgMatchingIndexProvider.overrideWithValue(buildIndex(150)),
          epgMatchingInputsReadyProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        currentProgramsForVisibleChannelsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);

      for (var id = 1; id <= 150; id++) {
        registry.register(_candidate(id));
      }
      await _waitFor(() => epgRepository.queries.isNotEmpty);

      expect(epgRepository.queries, hasLength(1));
      expect(epgRepository.queries.single, hasLength(64));
    });

    test('a replaced visible set discards the old bulk subscription', () async {
      final visibleController =
          StreamController<List<VisibleLiveChannelCandidate>>();
      addTearDown(visibleController.close);
      buildContainer(
        candidates: () => visibleController.stream,
        index: buildIndex(4),
      );

      visibleController.add([_candidate(1), _candidate(2)]);
      await _waitFor(() => epgRepository.queries.isNotEmpty);
      expect(epgRepository.queries, hasLength(1));
      expect(epgRepository.queries.single.toSet(), {'epg-1', 'epg-2'});

      visibleController.add([_candidate(3), _candidate(4)]);
      await _waitFor(() => epgRepository.queries.length >= 2);
      expect(epgRepository.queries, hasLength(2));
      expect(epgRepository.queries.last.toSet(), {'epg-3', 'epg-4'});
      expect(
        epgRepository.cancelCount,
        greaterThanOrEqualTo(1),
        reason: 'the old set subscription must be discarded',
      );
    });

    test('current programme titles resolve through the visible map', () async {
      final now = DateTime.now();
      epgRepository.entries = [
        EpgEntry(
          id: 1,
          channelId: 'epg-5',
          title: 'Jetzt live',
          startTime: now.subtract(const Duration(minutes: 5)),
          endTime: now.add(const Duration(minutes: 5)),
        ),
      ];
      final container = buildContainer(
        candidates: () =>
            Stream.value([_candidate(5), _candidate(6), _candidate(7)]),
        index: buildIndex(10),
      );

      final map = await container.read(
        currentProgramsForVisibleChannelsProvider.future,
      );

      expect(epgRepository.queries, hasLength(1));
      expect(epgRepository.queries.single, hasLength(3));
      expect(map[5]?.title, 'Jetzt live');
      expect(map[6], isNull);
    });
  });
}
