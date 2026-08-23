import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/api/xtream_client.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/imports/import_limit_exception.dart';
import 'package:m3uxtream_player/core/imports/import_limits.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/epg_sync_service.dart';
import 'package:m3uxtream_player/core/services/playlist_sync_service.dart';

import 'helpers/real_http_overrides.dart';

ImportLimits _integrationLimits({
  int transport = 1024 * 1024,
  int endpoint = 1024 * 1024,
  int decoded = 1024 * 1024,
  int records = 100,
  int lines = 100,
  int channels = 100,
  int categories = 100,
  int field = 64 * 1024,
  int persisted = 100,
  int depth = 32,
}) {
  return ImportLimits(
    maxTransportBytes: transport,
    maxEndpointTransportBytes: endpoint,
    maxDecodedBytes: decoded,
    maxRecords: records,
    maxLineRecords: lines,
    maxChannelRecords: channels,
    maxCategoryRecords: categories,
    maxFieldBytes: field,
    maxPersistedRows: persisted,
    maxXmlDepth: depth,
    maxDuration: const Duration(minutes: 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M3U record rejection preserves the previous catalogue', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = PlaylistRepository(db);
    final service = PlaylistSyncService(
      repository,
      m3uLimits: _integrationLimits(records: 1, channels: 1),
    );
    final playlistId = await repository.insertPlaylist(
      PlaylistsCompanion.insert(
        name: 'Budget M3U',
        type: 'm3u',
        urlOrHost: 'fixture.m3u',
      ),
    );

    await service.syncM3uPlaylist(
      playlistId: playlistId,
      m3uContent: '#EXTM3U\n#EXTINF:-1,Old\nhttps://safe/old\n',
    );
    await expectLater(
      service.syncM3uPlaylist(
        playlistId: playlistId,
        m3uContent:
            '#EXTM3U\n'
            '#EXTINF:-1,New One\nhttps://safe/one\n'
            '#EXTINF:-1,New Two\nhttps://safe/two\n',
      ),
      throwsA(isA<ImportLimitException>()),
    );

    final rows = await db.select(db.channels).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Old');
  });

  test('M3U transport limit rejects before parsing and persistence', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = PlaylistRepository(db);
    final tempDir = await Directory.systemTemp.createTemp('m3u_budget');
    addTearDown(() => tempDir.delete(recursive: true));
    final source = File('${tempDir.path}/large.m3u');
    await source.writeAsString(
      '#EXTM3U\n#EXTINF:-1,Replacement\nhttps://safe/replacement\n',
    );
    final playlistId = await repository.insertPlaylist(
      PlaylistsCompanion.insert(
        name: 'Transport M3U',
        type: 'm3u',
        urlOrHost: source.path,
      ),
    );
    await repository.syncM3uChannels(
      playlistId: playlistId,
      parsedChannels: const [
        ParsedChannel(
          name: 'Existing',
          streamUrl: 'https://safe/existing',
          channelType: 'live',
        ),
      ],
    );
    final service = PlaylistSyncService(
      repository,
      m3uLimits: _integrationLimits(transport: 8),
    );

    await expectLater(
      service.syncPlaylist(playlistId),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.transportBytes,
        ),
      ),
    );
    final rows = await db.select(db.channels).get();
    expect(rows.single.name, 'Existing');
  });

  test('Xtream endpoints share one aggregate transport budget', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('[]')
          ..close();
      });
      final host = 'http://${server.address.host}:${server.port}';
      final budget = ImportBudget(
        limits: _integrationLimits(transport: 3, endpoint: 2),
      );

      expect(
        await XtreamClient.fetchLiveCategories(
          host: host,
          username: 'user',
          password: 'pass',
          budget: budget,
        ),
        '[]',
      );
      await expectLater(
        XtreamClient.fetchLiveStreams(
          host: host,
          username: 'user',
          password: 'pass',
          budget: budget,
        ),
        throwsA(
          isA<ImportLimitException>().having(
            (error) => error.code,
            'code',
            ImportLimitCode.transportBytes,
          ),
        ),
      );
    }, RealHttpOverrides());
  });

  test('Xtream catalogue transport runs with at most two requests', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = PlaylistRepository(db);
      final service = PlaylistSyncService(repository);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var active = 0;
      var maximumActive = 0;
      server.listen((request) async {
        active++;
        if (active > maximumActive) maximumActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        request.response
          ..statusCode = HttpStatus.ok
          ..write('[]')
          ..close();
        active--;
      });
      final playlistId = await repository.insertPlaylist(
        PlaylistsCompanion(
          name: const Value('Controlled Xtream'),
          type: const Value('xtream'),
          urlOrHost: Value('http://${server.address.host}:${server.port}'),
          username: const Value('user'),
          password: const Value('pass'),
        ),
      );

      await service.syncPlaylist(playlistId);

      expect(maximumActive, 2);
      expect(await db.select(db.channels).get(), isEmpty);
    }, RealHttpOverrides());
  });

  test(
    'Xtream limit cancels outstanding requests and publishes nothing',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final db = AppDatabase.executor(NativeDatabase.memory());
        addTearDown(db.close);
        final repository = PlaylistRepository(db);
        final service = PlaylistSyncService(
          repository,
          xtreamLimits: _integrationLimits(transport: 4, endpoint: 4),
        );
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        var requested = 0;
        server.listen((request) async {
          requested++;
          final action = request.uri.queryParameters['action'];
          try {
            if (action == 'get_live_categories') {
              request.response
                ..statusCode = HttpStatus.ok
                ..write('[12345]')
                ..close();
              return;
            }
            await Future<void>.delayed(const Duration(seconds: 2));
            request.response
              ..statusCode = HttpStatus.ok
              ..write('[]')
              ..close();
          } on HttpException {
            // Expected: the shared cancellation closes the other client.
          }
        });
        final playlistId = await repository.insertPlaylist(
          PlaylistsCompanion(
            name: const Value('Cancelled Xtream'),
            type: const Value('xtream'),
            urlOrHost: Value('http://${server.address.host}:${server.port}'),
            username: const Value('user'),
            password: const Value('pass'),
          ),
        );
        final stopwatch = Stopwatch()..start();

        await expectLater(
          service.syncPlaylist(playlistId),
          throwsA(isA<ImportLimitException>()),
        );
        stopwatch.stop();

        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
        expect(requested, lessThanOrEqualTo(2));
        expect(await db.select(db.channels).get(), isEmpty);
      }, RealHttpOverrides());
    },
  );

  test('GZip expansion rejection preserves existing EPG rows', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final playlistRepository = PlaylistRepository(db);
    final epgRepository = EpgRepository(db);
    final playlistId = await playlistRepository.insertPlaylist(
      PlaylistsCompanion.insert(
        name: 'Budget XMLTV',
        type: 'm3u',
        urlOrHost: 'fixture.m3u',
      ),
    );
    await db
        .into(db.epgEntries)
        .insert(
          EpgEntriesCompanion.insert(
            playlistId: playlistId,
            channelId: 'old',
            title: 'Existing guide',
            startTime: DateTime(2030),
            endTime: DateTime(2030, 1, 1, 1),
          ),
        );
    final xml =
        '<tv><channel id="new"><display-name>New</display-name></channel>'
        '<programme start="20300101000000 +0000" '
        'stop="20300101010000 +0000" channel="new">'
        '<title>${List.filled(256, 'x').join()}</title></programme></tv>';
    final tempDir = await Directory.systemTemp.createTemp('xmltv_budget');
    addTearDown(() => tempDir.delete(recursive: true));
    final source = File('${tempDir.path}/guide.xml.gz');
    await source.writeAsBytes(gzip.encode(utf8.encode(xml)));
    final service = EpgSyncService(
      epgRepository,
      playlistRepository,
      xmltvLimits: _integrationLimits(decoded: 64),
    );

    await expectLater(
      service.syncEpg(playlistId: playlistId, urlOrFilePath: source.path),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.decodedBytes,
        ),
      ),
    );
    final rows = await db.select(db.epgEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Existing guide');
  });

  test(
    'XMLTV persistence rejection happens before any cache mutation',
    () async {
      final db = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(db.close);
      final playlistRepository = PlaylistRepository(db);
      final epgRepository = EpgRepository(db);
      final playlistId = await playlistRepository.insertPlaylist(
        PlaylistsCompanion.insert(
          name: 'Persist XMLTV',
          type: 'm3u',
          urlOrHost: 'fixture.m3u',
        ),
      );
      await db
          .into(db.epgEntries)
          .insert(
            EpgEntriesCompanion.insert(
              playlistId: playlistId,
              channelId: 'old',
              title: 'Existing guide',
              startTime: DateTime(2030),
              endTime: DateTime(2030, 1, 1, 1),
            ),
          );
      const xml =
          '<tv><channel id="new"><display-name>New</display-name></channel>'
          '<programme start="20300101000000 +0000" '
          'stop="20300101010000 +0000" channel="new">'
          '<title>New guide</title></programme></tv>';
      final tempDir = await Directory.systemTemp.createTemp('xmltv_persist');
      addTearDown(() => tempDir.delete(recursive: true));
      final source = File('${tempDir.path}/guide.xml');
      await source.writeAsString(xml);
      final service = EpgSyncService(
        epgRepository,
        playlistRepository,
        xmltvLimits: _integrationLimits(persisted: 1),
      );

      await expectLater(
        service.syncEpg(playlistId: playlistId, urlOrFilePath: source.path),
        throwsA(
          isA<ImportLimitException>().having(
            (error) => error.code,
            'code',
            ImportLimitCode.persistedRows,
          ),
        ),
      );
      final rows = await db.select(db.epgEntries).get();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Existing guide');
    },
  );

  test('explicit XMLTV cancellation kills the worker and preserves data', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(db.close);
    final playlistRepository = PlaylistRepository(db);
    final epgRepository = EpgRepository(db);
    final playlistId = await playlistRepository.insertPlaylist(
      PlaylistsCompanion.insert(
        name: 'Cancel XMLTV',
        type: 'm3u',
        urlOrHost: 'fixture.m3u',
      ),
    );
    final tempDir = await Directory.systemTemp.createTemp('xmltv_cancel');
    addTearDown(() => tempDir.delete(recursive: true));
    final source = File('${tempDir.path}/guide.xml');
    await source.writeAsString(
      '<tv>${List.filled(5000, '<channel id="x"><display-name>X</display-name></channel>').join()}</tv>',
    );
    final service = EpgSyncService(epgRepository, playlistRepository);

    final future = service.syncEpg(
      playlistId: playlistId,
      urlOrFilePath: source.path,
    );
    service.cancelSync(playlistId);
    await expectLater(
      future,
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.cancelled,
        ),
      ),
    );
    expect(await db.select(db.epgEntries).get(), isEmpty);
  });
}
