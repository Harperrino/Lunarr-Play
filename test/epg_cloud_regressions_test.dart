import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/epg_sync_service.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_filter_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/selected_channel_epg_provider.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/visible_live_channel_registry.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_filters.dart';
import 'package:m3uxtream_player/app/composition/player/widgets/player_epg_panel.dart';
import 'package:m3uxtream_player/app/composition/player/widgets/player_panel.dart';
import 'package:m3uxtream_player/app/composition/player/providers/player_ui_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';

import 'support/fake_media_player.dart';

Channel channel(int playlistId) => Channel(
  id: playlistId,
  playlistId: playlistId,
  providerOrder: 0,
  streamId: null,
  name: 'Channel $playlistId',
  logo: null,
  groupName: 'News',
  tvgId: 'shared.id',
  streamUrl: 'https://example.invalid/live',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'live',
);

EpgEntry programme(int id, DateTime start, DateTime end) => EpgEntry(
  id: id,
  playlistId: 2,
  channelId: 'shared.id',
  title: 'Programme $id',
  startTime: start,
  endTime: end,
  description: null,
);

class _ProgrammeRepository extends EpgRepository {
  _ProgrammeRepository(super.db, this.programmes);
  final List<EpgEntry> programmes;
  final List<Map<int, Set<String>>> requests = [];
  @override
  Stream<List<EpgEntry>> watchEntriesInRangeForPlaylistChannelIds(
    Map<int, Set<String>> ids,
    DateTime start,
    DateTime end,
  ) {
    requests.add(ids);
    return Stream.value(programmes);
  }
}

class _TestBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

void main() {
  test(
    'guide combines selected playlists without changing playback selection',
    () async {
      final container = ProviderContainer(
        overrides: [
          selectedPlaylistIdProvider.overrideWith((ref) => 1),
          epgPlaylistFilterProvider.overrideWith((ref) => {1, 2, 99}),
          playlistsStreamProvider.overrideWith(
            (ref) => Stream.value([
              for (final id in [1, 2])
                Playlist(
                  id: id,
                  name: 'Playlist $id',
                  type: 'm3u',
                  urlOrHost: 'fixture.m3u',
                  createdAt: DateTime(2030),
                ),
            ]),
          ),
          for (final id in [1, 2])
            playlistCatalogStreamProvider(
              PlaylistCatalogQuery(
                scope: PlaylistCatalogScope.single(id),
                mediaType: PlaylistCatalogMediaType.live,
              ),
            ).overrideWith((ref) => Stream.value([channel(id)])),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        epgGuideChannelsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(playlistsStreamProvider.future);
      for (final id in [1, 2]) {
        await container.read(
          playlistCatalogStreamProvider(
            PlaylistCatalogQuery(
              scope: PlaylistCatalogScope.single(id),
              mediaType: PlaylistCatalogMediaType.live,
            ),
          ).future,
        );
      }
      expect(
        container
            .read(epgGuideChannelsProvider)
            .requireValue
            .map((channel) => channel.playlistId),
        [1, 2],
      );
      expect(container.read(epgFilterPlaylistIdsProvider), [1, 2]);
      expect(container.read(selectedPlaylistIdProvider), 1);
      container.read(epgPlaylistFilterProvider.notifier).state = {};
      expect(container.read(epgGuideChannelsProvider).requireValue, isEmpty);
    },
  );

  test(
    'guide reports playlist loading and errors rather than an empty guide',
    () async {
      final stream = StreamController<List<Playlist>>();
      addTearDown(stream.close);
      final container = ProviderContainer(
        overrides: [
          epgPlaylistFilterProvider.overrideWith((ref) => {1}),
          playlistsStreamProvider.overrideWith((ref) => stream.stream),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        epgGuideChannelsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(container.read(epgGuideChannelsProvider).isLoading, isTrue);
      final error = StateError('playlist unavailable');
      stream.addError(error);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(epgGuideChannelsProvider).error, same(error));
    },
  );

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets(
    'windowed player keeps EPG below its controls at compact heights',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('No database in this layout test'),
          ),
          selectedChannelProvider.overrideWith((ref) => channel(2)),
          epgCurrentMinuteProvider.overrideWithValue(DateTime(2030)),
          currentProgramTitleForSelectedChannelProvider.overrideWith(
            (ref) => null,
          ),
          selectedChannelProgrammesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          playerBufferSecondsProvider.overrideWith(
            _TestBufferSecondsNotifier.new,
          ),
          playerNotifierProvider.overrideWith(
            () => FixedPlayerNotifier(
              PlayerState(
                player: FakeMediaPlayer(),
                playbackUri: null,
                isPlaying: false,
                volume: 0.5,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      for (final height in [600.0, 420.0, 280.0]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: app(
              SizedBox(
                width: 800,
                height: height,
                child: PlayerPanel(key: ValueKey(height)),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final stage = tester.getRect(
          find.byKey(const ValueKey('windowed-player-stage')),
        );
        final epg = tester.getRect(
          find.byKey(const ValueKey('player-epg-panel')),
        );
        expect(epg.top, greaterThan(stage.bottom));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('guide picker applies multiple selections and can cancel edits', (
    tester,
  ) async {
    Set<int>? chosen;
    await tester.pumpWidget(
      app(
        EpgFilterButton<int>(
          title: 'Playlists',
          options: const [
            EpgFilterOption(1, 'First'),
            EpgFilterOption(2, 'Second'),
          ],
          selected: const {1, 2},
          onChanged: (value) => chosen = value,
        ),
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(chosen, {2});
    chosen = null;
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select none'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'player panel shows the selected channel current and next programme',
    (tester) async {
      final now = DateTime(2030, 1, 1, 12);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedChannelProvider.overrideWith((ref) => channel(2)),
            epgCurrentMinuteProvider.overrideWithValue(now),
            selectedChannelProgrammesProvider.overrideWith(
              (ref) => Stream.value([
                programme(
                  2,
                  now.subtract(const Duration(minutes: 30)),
                  now.add(const Duration(minutes: 30)),
                ),
                programme(
                  3,
                  now.add(const Duration(minutes: 30)),
                  now.add(const Duration(hours: 1)),
                ),
              ]),
            ),
          ],
          child: app(const PlayerEpgPanel(compact: false)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Programme 2'), findsOneWidget);
      expect(find.textContaining('Programme 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('player-epg-panel')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'visible channel programme advances on the minute tick without scrolling',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.fromMillisecondsSinceEpoch(
        (DateTime.now().millisecondsSinceEpoch ~/ 60000) * 60000,
      );
      final repository = _ProgrammeRepository(db, [
        programme(
          2,
          now.subtract(const Duration(hours: 1)),
          now.add(const Duration(minutes: 1)),
        ),
        programme(
          3,
          now.add(const Duration(minutes: 1)),
          now.add(const Duration(hours: 1)),
        ),
      ]);
      final ticks = StreamController<DateTime>();
      addTearDown(ticks.close);
      final container = ProviderContainer(
        overrides: [
          epgRepositoryProvider.overrideWithValue(repository),
          visibleLiveChannelCandidatesProvider.overrideWith(
            (ref) => Stream.value(const [
              VisibleLiveChannelCandidate(
                channelId: 2,
                playlistId: 2,
                name: 'News',
                tvgId: 'shared.id',
              ),
            ]),
          ),
          epgMatchingInputsReadyProvider.overrideWithValue(true),
          epgMatchingIndexProvider.overrideWithValue(
            PlaylistEpgMatchingIndex(
              knownEpgChannelIdsByPlaylist: const {
                2: {'shared.id'},
              },
              displayNamesByPlaylist: const {},
            ),
          ),
          epgGridMinuteTickProvider.overrideWith((ref) => ticks.stream),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        currentProgramsForVisibleChannelsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        (await container.read(
          currentProgramsForVisibleChannelsProvider.future,
        ))[2]?.id,
        2,
      );
      ticks.add(now.add(const Duration(minutes: 1)));
      for (
        var i = 0;
        i < 100 &&
            container
                    .read(currentProgramsForVisibleChannelsProvider)
                    .valueOrNull?[2]
                    ?.id !=
                3;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        container
            .read(currentProgramsForVisibleChannelsProvider)
            .requireValue[2]
            ?.id,
        3,
      );
    },
  );

  test(
    'HTTP Content-Encoding gzip is decoded once before XMLTV persistence',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(db.close);
      final playlists = PlaylistRepository(db);
      final id = await playlists.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Gzip test',
          type: 'm3u',
          urlOrHost: 'fixture.m3u',
        ),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscription = server.listen((request) async {
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        request.response.add(
          gzip.encode(
            utf8.encode(
              '<tv><channel id="shared.id"><display-name>News</display-name></channel>'
              '<programme channel="shared.id" start="20300101120000 +0000" stop="20300101130000 +0000">'
              '<title>Gzipped programme</title></programme></tv>',
            ),
          ),
        );
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      await EpgSyncService(EpgRepository(db), playlists).syncEpg(
        playlistId: id,
        urlOrFilePath: 'http://127.0.0.1:${server.port}/guide.xml',
      );
      final rows = await db.select(db.epgEntries).get();
      expect(rows.single.title, 'Gzipped programme');
      expect(rows.single.playlistId, id);
    },
  );

  test(
    'a new visible-row subscriber replays an unchanged registered set',
    () async {
      final registry = VisibleLiveChannelRegistry(publishDelay: Duration.zero);
      addTearDown(registry.dispose);
      registry.register(
        const VisibleLiveChannelCandidate(
          channelId: 2,
          playlistId: 2,
          name: 'News',
          tvgId: 'shared.id',
        ),
      );
      await registry.changes.first;
      final container = ProviderContainer(
        overrides: [
          visibleLiveChannelRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(visibleLiveChannelCandidatesProvider.future),
        contains(
          isA<VisibleLiveChannelCandidate>().having(
            (c) => c.channelId,
            'channelId',
            2,
          ),
        ),
      );
      container.invalidate(visibleLiveChannelCandidatesProvider);
      expect(
        await container.read(visibleLiveChannelCandidatesProvider.future),
        hasLength(1),
      );
    },
  );

  test('category filters preserve playlist identity and an empty selection stays empty', () {
    final channels = [channel(1), channel(2)];
    expect(
      filterEpgGuideChannels(
        channels: channels,
        categories: {playlistCatalogCategoryKey(2, 'News')},
        search: '',
      ),
      [channel(2)],
    );
    expect(
      filterEpgGuideChannels(channels: channels, categories: {}, search: ''),
      isEmpty,
    );
    expect(
      filterEpgGuideChannels(
        channels: channels,
        categories: null,
        search: 'channel 1',
      ),
      [channel(1)],
    );
  });

  test('programme changes at the exact end boundary and next is chronologically earliest', () {
    final now = DateTime.utc(2030, 1, 1, 12);
    final entries = [
      programme(
        3,
        now.add(const Duration(hours: 2)),
        now.add(const Duration(hours: 3)),
      ),
      programme(1, now.subtract(const Duration(hours: 1)), now),
      programme(2, now, now.add(const Duration(hours: 1))),
    ];
    final result = selectCurrentAndNextProgramme(entries, now);
    expect(result.current?.id, 2);
    expect(result.next?.id, 3);
  });

  test('playing-channel guide is playlist scoped and independent of browse filters', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    final repository = _ProgrammeRepository(db, [
      programme(
        2,
        now.subtract(const Duration(minutes: 1)),
        now.add(const Duration(hours: 1)),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        epgRepositoryProvider.overrideWithValue(repository),
        selectedChannelProvider.overrideWith((ref) => channel(2)),
        epgMatchingInputsReadyProvider.overrideWithValue(true),
        epgMatchingIndexProvider.overrideWithValue(
          PlaylistEpgMatchingIndex(
            knownEpgChannelIdsByPlaylist: const {
              1: {'shared.id'},
              2: {'shared.id'},
            },
            displayNamesByPlaylist: const {},
          ),
        ),
        epgGridMinuteTickProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      selectedChannelProgrammesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    expect(
      (await container.read(selectedChannelProgrammesProvider.future))
          .single
          .playlistId,
      2,
    );
    final requestsBefore = repository.requests.length;
    container.read(epgPlaylistFilterProvider.notifier).state = {1};
    container.read(epgCategoryFilterProvider.notifier).state = {};
    container.read(epgWindowStartProvider.notifier).state = now.add(
      const Duration(days: 7),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.requests.length, requestsBefore);
    expect(repository.requests.last, {
      2: {'shared.id'},
    });
  });
}
