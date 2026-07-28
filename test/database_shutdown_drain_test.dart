import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/search/search_index_repository.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';
import 'package:m3uxtream_player/app/services/riverpod_app_shutdown_actions.dart';
import 'package:m3uxtream_player/core/services/epg_auto_refresh_coordinator.dart';
import 'package:m3uxtream_player/core/services/epg_sync_controller.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';

/// Holds the first call of one armed executor method until [release] fires.
/// This turns fast in-memory operations into deterministic lifecycle probes.
class _BlockingInterceptor extends QueryInterceptor {
  String? _blockedMethod;
  bool _holds = false;
  Completer<void>? _release;
  final Completer<void> _entered = Completer<void>();

  Future<void> get entered => _entered.future;

  void arm(String method) => _blockedMethod = method;

  void release() => _release?.complete();

  Future<T> _hold<T>(String method, Future<T> Function() operation) async {
    if (_blockedMethod == method && !_holds) {
      _holds = true;
      _release = Completer<void>();
      if (!_entered.isCompleted) _entered.complete();
      await _release!.future;
    }
    return operation();
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      _hold('ensureOpen', () => executor.ensureOpen(user));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _hold('runBatched', () => executor.runBatched(statements));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _hold('runCustom', () => executor.runCustom(statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _hold('runInsert', () => executor.runInsert(statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _hold('runDelete', () => executor.runDelete(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _hold('runUpdate', () => executor.runUpdate(statement, args));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _hold('runSelect', () => executor.runSelect(statement, args));
}

class _TestRig {
  const _TestRig({
    required this.db,
    required this.repository,
    required this.searchIndex,
    required this.gate,
    required this.interceptor,
    required this.playlistId,
    required this.channelId,
  });

  final AppDatabase db;
  final PlaylistRepository repository;
  final SearchIndexRepository searchIndex;
  final AppLifecycleGate gate;
  final _BlockingInterceptor interceptor;
  final int playlistId;
  final int channelId;
}

Future<_TestRig> _seededRig() async {
  final gate = AppLifecycleGate();
  final interceptor = _BlockingInterceptor();
  final db = AppDatabase.executor(
    NativeDatabase.memory().interceptWith(interceptor),
  );
  final repository = PlaylistRepository(db, lifecycleGate: gate);
  final searchIndex = SearchIndexRepository(db, lifecycleGate: gate);
  final playlistId = await repository.insertPlaylist(
    PlaylistsCompanion.insert(
      name: 'Drain Test',
      type: 'm3u',
      urlOrHost: 'redacted-test-source',
    ),
  );
  await repository.syncM3uChannels(
    playlistId: playlistId,
    parsedChannels: const [
      ParsedChannel(
        name: 'Channel One',
        streamUrl: 'https://example.invalid/one',
        channelType: 'live',
      ),
    ],
  );
  final channels = await db.select(db.channels).get();
  return _TestRig(
    db: db,
    repository: repository,
    searchIndex: searchIndex,
    gate: gate,
    interceptor: interceptor,
    playlistId: playlistId,
    channelId: channels.single.id,
  );
}

/// Starts [job], begins shutdown and proves the drain completes only after
/// the held database job is released.
Future<void> _expectDrainWaitsForHeldJob(
  _TestRig rig,
  Future<Object?> Function() job,
) async {
  await rig.interceptor.entered;

  rig.gate.beginShutdown();
  var drained = false;
  final drainFuture = rig.gate.drain().then((_) => drained = true);

  await Future<void>.delayed(const Duration(milliseconds: 10));
  expect(drained, isFalse, reason: 'drain must wait for the held DB job');

  rig.interceptor.release();
  await job();
  await drainFuture;
  expect(drained, isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('drain waits for an active favorite transaction before DB close', () async {
    final rig = await _seededRig();
    addTearDown(rig.db.close);

    rig.interceptor.arm('runUpdate');
    final toggle = rig.repository.toggleChannelFavorite(rig.channelId);

    await _expectDrainWaitsForHeldJob(rig, () => toggle);
    expect(await rig.db.select(rig.db.channels).get(), isNotEmpty);
  });

  test('drain waits for an active search before DB close', () async {
    final rig = await _seededRig();
    addTearDown(rig.db.close);

    rig.interceptor.arm('runSelect');
    final search = rig.searchIndex.search(
      SearchRequest(
        query: 'Channel',
        tab: SearchResultTab.all,
        activePlaylistIds: {rig.playlistId},
        limit: 12,
      ),
    );

    await _expectDrainWaitsForHeldJob(rig, () => search);
  });

  test('drain waits for an active playlist sync before DB close', () async {
    final rig = await _seededRig();
    addTearDown(rig.db.close);

    rig.interceptor.arm('runDelete');
    final sync = rig.repository.syncM3uChannels(
      playlistId: rig.playlistId,
      parsedChannels: const [
        ParsedChannel(
          name: 'Channel Two',
          streamUrl: 'https://example.invalid/two',
          channelType: 'live',
        ),
      ],
    );

    await _expectDrainWaitsForHeldJob(rig, () => sync);
  });

  test('no new database operation starts after shutdown begins', () async {
    final rig = await _seededRig();
    addTearDown(rig.db.close);

    rig.gate.beginShutdown();

    expect(
      () => rig.repository.toggleChannelFavorite(rig.channelId),
      throwsStateError,
    );
    expect(
      () => rig.repository.syncM3uChannels(
        playlistId: rig.playlistId,
        parsedChannels: const [],
      ),
      throwsStateError,
    );
    expect(() => rig.repository.deletePlaylist(rig.playlistId), throwsStateError);
    expect(
      () => rig.searchIndex.search(
        SearchRequest(
          query: 'Channel',
          tab: SearchResultTab.all,
          activePlaylistIds: {rig.playlistId},
        ),
      ),
      throwsStateError,
    );
    expect(() => rig.searchIndex.rebuildPlaylist(rig.playlistId), throwsStateError);
    expect(() => rig.searchIndex.ensureExistingIndexes(), throwsStateError);
    expect(() => rig.searchIndex.retryIncompleteIndexes(), throwsStateError);
  });

  test('a failing job neither blocks the drain nor escapes unhandled', () async {
    final rig = await _seededRig();
    addTearDown(rig.db.close);

    final failing = rig.repository.toggleChannelFavorite(9999);
    await expectLater(failing, throwsStateError);

    rig.gate.beginShutdown();
    await rig.gate.drain();
    await rig.db.close();
  });

  group('shutdown order', () {
    final calls = <String>[];

    setUp(calls.clear);

    Future<void> runPrepareForShutdown() async {
      final gate = _RecordingGate(calls);
      final epgController = _RecordingEpgController(calls);
      final coordinator = _RecordingCoordinator(calls, epgController);
      final searchIndex = _RecordingSearchIndex(calls);
      final container = ProviderContainer(
        overrides: [
          appLifecycleGateProvider.overrideWithValue(gate),
          epgSyncControllerProvider.overrideWithValue(epgController),
          epgAutoRefreshCoordinatorProvider.overrideWithValue(coordinator),
          searchIndexRepositoryProvider.overrideWithValue(searchIndex),
        ],
      );
      addTearDown(container.dispose);
      final actionsProvider = Provider<RiverpodAppShutdownActions>(
        RiverpodAppShutdownActions.new,
      );
      await container.read(actionsProvider).prepareForShutdown();
    }

    test('prepareForShutdown closes gate first and disposes services last', () async {
      await runPrepareForShutdown();

      expect(calls, [
        'gate.beginShutdown',
        'coordinator.dispose',
        'epg.drain',
        'search.beginShutdown',
        'search.drain',
        'gate.drain',
        'search.dispose',
        'epg.dispose',
      ]);
    });
  });
}

class _RecordingGate extends AppLifecycleGate {
  _RecordingGate(this.calls);

  final List<String> calls;

  @override
  void beginShutdown() {
    calls.add('gate.beginShutdown');
    super.beginShutdown();
  }

  @override
  Future<void> drain() {
    calls.add('gate.drain');
    return super.drain();
  }
}

class _RecordingEpgController extends EpgSyncController {
  _RecordingEpgController(this.calls) : super(sync: (_) async {});

  final List<String> calls;

  @override
  Future<void> drain() {
    calls.add('epg.drain');
    return Future.value();
  }

  @override
  Future<void> dispose() {
    calls.add('epg.dispose');
    return Future.value();
  }
}

class _RecordingCoordinator extends EpgAutoRefreshCoordinator {
  _RecordingCoordinator(this.calls, EpgSyncController controller)
    : super(
        controller: controller,
        loadPlaylists: () async => const [],
        loadInactivePlaylistIds: () async => const <int>{},
        loadInterval: (_) async => EpgRefreshInterval.manual,
      );

  final List<String> calls;

  @override
  Future<void> dispose() {
    calls.add('coordinator.dispose');
    return Future.value();
  }
}

class _RecordingSearchIndex extends SearchIndexRepository {
  _RecordingSearchIndex(this.calls)
    : super(
        AppDatabase.executor(NativeDatabase.memory()),
        lifecycleGate: null,
      );

  final List<String> calls;

  @override
  void beginShutdown() => calls.add('search.beginShutdown');

  @override
  Future<void> drain() {
    calls.add('search.drain');
    return Future.value();
  }

  @override
  Future<void> dispose() {
    calls.add('search.dispose');
    return Future.value();
  }
}
