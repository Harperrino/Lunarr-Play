import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/playlist_sync_service.dart';

import 'helpers/real_http_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistSyncService', () {
    late AppDatabase db;
    late PlaylistRepository repository;
    late PlaylistSyncService syncService;

    setUp(() {
      db = AppDatabase.executor(NativeDatabase.memory());
      repository = PlaylistRepository(db);
      syncService = PlaylistSyncService(repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('syncPlaylist writes lastSyncedAt atomically', () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async => server.close(force: true));

        const m3uContent = '''
#EXTM3U
#EXTINF:-1,Test Channel
https://example.com/live/test.m3u8
''';

        server.listen((request) async {
          if (request.uri.path != '/playlist.m3u') {
            request.response
              ..statusCode = HttpStatus.notFound
              ..close();
            return;
          }

          request.response
            ..statusCode = HttpStatus.ok
            ..write(m3uContent)
            ..close();
        });

        final playlistId = await repository.insertPlaylist(
          PlaylistsCompanion.insert(
            name: 'Sync Test',
            type: 'm3u',
            urlOrHost:
                'http://${server.address.host}:${server.port}/playlist.m3u',
          ),
        );

        await syncService.syncPlaylist(playlistId);

        final playlist = await repository.getPlaylistById(playlistId);
        expect(playlist?.lastSyncedAt, isNotNull);
        expect(await db.select(db.channels).get(), hasLength(1));
      }, RealHttpOverrides());
    });

    test(
      'syncPlaylist serializes concurrent requests for the same playlist',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() async => server.close(force: true));

          const m3uContent = '''
#EXTM3U
#EXTINF:-1,Test Channel
https://example.com/live/test.m3u8
''';

          var requestCount = 0;
          final readyToRespond = Completer<void>();

          server.listen((request) async {
            if (request.uri.path != '/playlist.m3u') {
              request.response
                ..statusCode = HttpStatus.notFound
                ..close();
              return;
            }

            requestCount += 1;
            if (!readyToRespond.isCompleted) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              readyToRespond.complete();
            }
            await readyToRespond.future;

            request.response
              ..statusCode = HttpStatus.ok
              ..write(m3uContent)
              ..close();
          });

          final playlistId = await repository.insertPlaylist(
            PlaylistsCompanion.insert(
              name: 'Sync Test',
              type: 'm3u',
              urlOrHost:
                  'http://${server.address.host}:${server.port}/playlist.m3u',
            ),
          );

          final first = syncService.syncPlaylist(playlistId);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final second = syncService.syncPlaylist(playlistId);

          await Future.wait([first, second]);

          expect(requestCount, 1);
          expect(
            (await repository.getPlaylistById(playlistId))?.lastSyncedAt,
            isNotNull,
          );
        }, RealHttpOverrides());
      },
    );
  });
}
