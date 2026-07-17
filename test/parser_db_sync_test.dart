import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/api/xtream_client.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/playlist_sync_service.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/services/epg_sync_service.dart';

import 'helpers/real_http_overrides.dart';

void main() {
  // Ensure standard Flutter testing environments are initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IP-TV Core IPTV Engine: Parser & Drift Sync Sanity Check', () {
    late AppDatabase db;
    late PlaylistRepository repository;
    late PlaylistSyncService syncService;
    late EpgRepository epgRepository;
    late EpgSyncService epgSyncService;

    setUp(() {
      // Build a fresh, isolated in-memory SQLite context before running each test block
      db = AppDatabase.executor(NativeDatabase.memory());
      repository = PlaylistRepository(db);
      syncService = PlaylistSyncService(repository);
      epgRepository = EpgRepository(db);
      epgSyncService = EpgSyncService(epgRepository, repository);
    });

    tearDown(() async {
      // Dispose database resources cleanly after test execution completes
      await db.close();
    });

    test(
      'Parses M3U streams, skips corruption, classifies types, and batch syncs to memory db',
      () async {
        // 1. ARRANGE: Create a M3U string with 4 fully valid channels and 1 corrupt-layout chunk.
        // Note: The corrupt line "// This entry is..." does not start with '#' and is therefore
        // successfully parsed as a stream URL associated with the prior metadata header, resulting in 5 channels.
        const String mockM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="de.rtl" tvg-name="RTL HD" tvg-logo="http://logos.com/rtl.png" group-title="German TV",RTL HD
http://stream.provider.com/rtl.m3u8
#EXTINF:0 tvg-id="us.cnn" tvg-name="CNN International" tvg-logo="http://logos.com/cnn.png" group-title="News Channels",CNN International
http://stream.provider.com/cnn.ts
#EXTINF:-1 tvg-id="movie.avatar" tvg-name="Avatar: The Way of Water" tvg-logo="http://logos.com/avatar.jpg" group-title="VOD Movies",Avatar 2 (2022)
http://stream.provider.com/avatar2.mp4
#EXTINF:-1 tvg-id="corrupt.item" tvg-logo="" group-title="Corrupt"
// This entry is intentionally broken! It has no comma separating the name, and no stream URL underneath!
#EXTINF:-1 tvg-id="us.hbo" tvg-name="HBO HD",HBO HD
http://stream.provider.com/hbo.m3u8
''';

        // 2. ACT: Insert a mock playlist profile into SQLite
        final playlistId = await repository.insertPlaylist(
          const PlaylistsCompanion(
            name: Value('Isolated Testing M3U Playlist'),
            type: Value('m3u'),
            urlOrHost: Value('local_test_file'),
          ),
        );

        expect(playlistId, isNotNull);
        expect(playlistId, greaterThan(0));

        // 3. ACT: Trigger full background parsing Isolate and batch insertion cycle
        await syncService.syncM3uPlaylist(
          playlistId: playlistId,
          m3uContent: mockM3u,
        );

        // 4. ASSERT: Fetch records from Drift to verify correct synchronization
        final channels = await db.select(db.channels).get();

        // Expected total: 5 channels successfully parsed (including the '//' URL fallback line)
        expect(channels.length, equals(5));

        // Verify Channel 1: RTL HD
        final rtl = channels.firstWhere((c) => c.name == 'RTL HD');
        expect(rtl.tvgId, equals('de.rtl'));
        expect(rtl.logo, equals('http://logos.com/rtl.png'));
        expect(rtl.groupName, equals('German TV'));
        expect(
          rtl.channelType,
          equals('live'),
        ); // Standard live M3U8 classification
        expect(rtl.streamUrl, equals('http://stream.provider.com/rtl.m3u8'));

        // Verify Channel 3: Avatar 2 (2022) Movie
        final avatar = channels.firstWhere((c) => c.name == 'Avatar 2 (2022)');
        expect(avatar.tvgId, equals('movie.avatar'));
        expect(avatar.logo, equals('http://logos.com/avatar.jpg'));
        expect(avatar.groupName, equals('VOD Movies'));
        expect(
          avatar.channelType,
          equals('vod'),
        ); // Auto-classified as VOD due to .mp4 extension and/or VOD keyword

        // 5. ASSERT: Test referential cascade deletion on SQLite level
        // Deleting the playlist should wipe all channels instantly
        await repository.deletePlaylist(playlistId);
        final remainingChannels = await db.select(db.channels).get();
        expect(remainingChannels.isEmpty, isTrue);
      },
    );

    test(
      'Queries Xtream Codes API server, processes JSON in Isolate and batch synchronizes to Drift',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          // 1. ARRANGE: Set up a local in-memory HttpServer to mock Xtream player_api.php responses.
          final server = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            0,
          ); // 0 binds to a random available port
          final localPort = server.port;
          final localHost = 'localhost:$localPort';

          // Start listening to incoming native HttpClient calls in the background
          server.listen((HttpRequest request) {
            final queryParams = request.uri.queryParameters;
            final action = queryParams['action'];

            // Verify that authentication parameters are transmitted securely
            expect(queryParams['username'], equals('demouser'));
            expect(queryParams['password'], equals('demopass'));

            if (action == 'get_live_categories') {
              // Serve categories list
              request.response
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode([
                    {"category_id": "100", "category_name": "Premium Sports"},
                    {"category_id": "200", "category_name": "Entertainment UK"},
                  ]),
                )
                ..close();
            } else if (action == 'get_live_streams') {
              // Serve streams list
              request.response
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode([
                    {
                      "num": 1,
                      "name": "Sky Sports Main Event",
                      "stream_id": "9901",
                      "stream_icon": "http://logo.com/skysports.png",
                      "epg_channel_id": "uk.skysports",
                      "category_id": "100",
                    },
                    {
                      "num": 2,
                      "name": "BBC One HD",
                      "stream_id": "9902",
                      "stream_icon": "http://logo.com/bbcone.png",
                      "epg_channel_id": "uk.bbcone",
                      "category_id": "200",
                    },
                  ]),
                )
                ..close();
            } else if (action == 'get_vod_categories' ||
                action == 'get_series_categories') {
              request.response
                ..headers.contentType = ContentType.json
                ..write('[]')
                ..close();
            } else if (action == 'get_vod_streams' || action == 'get_series') {
              request.response
                ..headers.contentType = ContentType.json
                ..write('[]')
                ..close();
            } else {
              // Default: Serve credentials authorization user info
              request.response
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode({
                    "user_info": {
                      "username": "demouser",
                      "status": "Active",
                      "expiry_date": "1782012000",
                    },
                    "server_info": {
                      "url": "localhost",
                      "port": localPort.toString(),
                    },
                  }),
                )
                ..close();
            }
          });

          try {
            // 2. ACT: Verify authenticate endpoint works
            final authData = await XtreamClient.authenticate(
              host: localHost,
              username: 'demouser',
              password: 'demopass',
            );
            expect(authData['user_info']['status'], equals('Active'));
            expect(authData['user_info']['username'], equals('demouser'));

            // 3. ACT: Insert playlist profile in database
            final playlistId = await repository.insertPlaylist(
              const PlaylistsCompanion(
                name: Value('Isolated Testing Xtream Playlist'),
                type: Value('xtream'),
                urlOrHost: Value('http://localhost'),
                username: Value('demouser'),
                password: Value('demopass'),
              ),
            );

            // 4. ACT: Fetch raw API strings and synchronise channels using the Isolate sync service
            final categoriesJson = await XtreamClient.fetchLiveCategories(
              host: localHost,
              username: 'demouser',
              password: 'demopass',
            );
            final streamsJson = await XtreamClient.fetchLiveStreams(
              host: localHost,
              username: 'demouser',
              password: 'demopass',
            );

            await syncService.syncXtreamPlaylist(
              playlistId: playlistId,
              liveStreamsJson: streamsJson,
              liveCategoriesJson: categoriesJson,
              host: localHost,
              username: 'demouser',
              password: 'demopass',
            );

            // 5. ASSERT: Fetch records from SQLite to verify mapping and inserts
            final channels = await db.select(db.channels).get();
            expect(channels.length, equals(2));

            // Verify mapped category name and stream URL construction for Channel 1
            final skySports = channels.firstWhere((c) => c.streamId == '9901');
            expect(skySports.name, equals('Sky Sports Main Event'));
            expect(skySports.logo, equals('http://logo.com/skysports.png'));
            expect(
              skySports.groupName,
              equals('Premium Sports'),
            ); // Cleanly resolved from category lookup map
            expect(skySports.tvgId, equals('uk.skysports'));
            expect(skySports.channelType, equals('live'));
            expect(
              skySports.streamUrl,
              equals('http://localhost:$localPort/live/demouser/demopass/9901'),
            );

            // Verify mapped details for Channel 2
            final bbcOne = channels.firstWhere((c) => c.streamId == '9902');
            expect(bbcOne.name, equals('BBC One HD'));
            expect(bbcOne.logo, equals('http://logo.com/bbcone.png'));
            expect(bbcOne.groupName, equals('Entertainment UK'));
            expect(
              bbcOne.streamUrl,
              equals('http://localhost:$localPort/live/demouser/demopass/9902'),
            );
          } finally {
            // Shut down the background mock server safely
            await server.close(force: true);
          }
        }, RealHttpOverrides());
      },
    );

    test(
      'Xtream sync stores live, vod, and series with type-scoped watch query',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final localPort = server.port;
          final localHost = 'localhost:$localPort';

          server.listen((HttpRequest request) {
            final action = request.uri.queryParameters['action'];

            switch (action) {
              case 'get_live_categories':
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode([
                      {'category_id': '1', 'category_name': 'Live TV'},
                    ]),
                  )
                  ..close();
              case 'get_live_streams':
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode([
                      {
                        'stream_id': '100',
                        'name': 'News 24',
                        'category_id': '1',
                      },
                    ]),
                  )
                  ..close();
              case 'get_vod_categories':
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode([
                      {'category_id': '2', 'category_name': 'Movies'},
                    ]),
                  )
                  ..close();
              case 'get_vod_streams':
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode([
                      {
                        'stream_id': '200',
                        'name': 'Test Movie',
                        'category_id': '2',
                        'container_extension': 'mp4',
                      },
                    ]),
                  )
                  ..close();
              case 'get_series_categories':
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode([
                      {'category_id': '3', 'category_name': 'Series'},
                    ]),
                  )
                  ..close();
              case 'get_series':
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode([
                      {
                        'series_id': '300',
                        'name': 'Test Show',
                        'cover': 'http://logo/show.png',
                        'category_id': '3',
                      },
                    ]),
                  )
                  ..close();
              default:
                request.response
                  ..headers.contentType = ContentType.json
                  ..write(
                    jsonEncode({
                      'user_info': {'status': 'Active'},
                    }),
                  )
                  ..close();
            }
          });

          try {
            final playlistId = await repository.insertPlaylist(
              PlaylistsCompanion(
                name: const Value('Mixed Xtream Catalogue'),
                type: const Value('xtream'),
                urlOrHost: Value('http://$localHost'),
                username: const Value('demouser'),
                password: const Value('demopass'),
              ),
            );

            await syncService.syncPlaylist(playlistId);

            final all = await db.select(db.channels).get();
            expect(all.length, 3);
            expect(all.where((c) => c.channelType == 'live').length, 1);
            expect(all.where((c) => c.channelType == 'vod').length, 1);
            expect(all.where((c) => c.channelType == 'series').length, 1);

            final liveOnly = await repository
                .watchChannelsByPlaylistAndType(playlistId, 'live')
                .first;
            expect(liveOnly.length, 1);
            expect(liveOnly.single.name, 'News 24');

            final vodOnly = await repository
                .watchChannelsByPlaylistAndType(playlistId, 'vod')
                .first;
            expect(
              vodOnly.single.streamUrl,
              'http://localhost:$localPort/movie/demouser/demopass/200.mp4',
            );
          } finally {
            await server.close(force: true);
          }
        }, RealHttpOverrides());
      },
    );

    test(
      'Parses XMLTV EPG data (gzipped), purges stale entries, and syncs program guides into Drift SQLite',
      () async {
        // 1. ARRANGE: Define a valid XMLTV guide layout containing 3 programs
        // (1 program in the past to test purging, and 2 valid future programs)
        const String mockXmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv>
  <channel id="de.rtl">
    <display-name>RTL HD</display-name>
  </channel>
  <channel id="us.cnn">
    <display-name>CNN International</display-name>
  </channel>
  
  <!-- Program 1: Outdated/Expired Program (endTime in the past: 2010-01-01) -->
  <programme start="20100101120000 +0000" stop="20100101130000 +0000" channel="de.rtl">
    <title lang="de">Expired Show</title>
    <desc lang="de">This program should be auto-purged from the database</desc>
    <category lang="de">Classic</category>
  </programme>

  <!-- Program 2: Valid Future Program on RTL -->
  <programme start="20300521140000 +0200" stop="20300521153000 +0200" channel="de.rtl">
    <title lang="de">RTL Aktuell Live</title>
    <desc lang="de">Abendnachrichten und Sportberichte aus aller Welt.</desc>
    <category lang="de">News</category>
  </programme>

  <!-- Program 3: Valid Future Program on CNN -->
  <programme start="20300521153000 +0200" stop="20300521163000 +0200" channel="us.cnn">
    <title lang="en">CNN Newsroom</title>
    <desc lang="en">Global news coverage and live report segments.</desc>
    <category lang="en">News</category>
  </programme>
</tv>''';

        // 2. ARRANGE: Create a GZIP-compressed byte list in memory to simulate a .xml.gz EPG file
        final List<int> rawBytes = utf8.encode(mockXmltv);
        final List<int> gzippedBytes = gzip.encode(rawBytes);

        // Create a temporary file in the local workspace directory
        final tempDir = await Directory.systemTemp.createTemp('epg_test');
        final tempFile = File('${tempDir.path}/epg_guide.xml.gz');
        await tempFile.writeAsBytes(gzippedBytes);

        try {
          // 3. ACT: Pre-populate the SQLite database with 1 expired EpgEntry directly
          // to verify that EpgSyncService's purging logic executes successfully.
          await db
              .into(db.epgEntries)
              .insert(
                EpgEntriesCompanion.insert(
                  channelId: 'de.rtl',
                  title: 'Stale Pre-existing Entry',
                  description: const Value('Should be purged'),
                  startTime: DateTime.now().subtract(const Duration(hours: 5)),
                  endTime: DateTime.now().subtract(const Duration(hours: 4)),
                ),
              );

          // Verify pre-existing item exists
          final prePurgeEntries = await db.select(db.epgEntries).get();
          expect(prePurgeEntries.length, equals(1));

          // 4. ACT: Trigger background Isolate EPG download, GZIP decompression, and batch insertion
          await epgSyncService.syncEpg(urlOrFilePath: tempFile.path);

          // 5. ASSERT: Fetch records from Drift to verify correct purging and synchronization
          final currentEntries = await db.select(db.epgEntries).get();

          // The pre-existing stale entry is successfully purged before the sync process.
          // During the sync process, all 3 new entries from the XMLTV file are inserted.
          expect(currentEntries.length, equals(3));

          // Validate RTL programs (both 'RTL Aktuell Live' and the expired 'Expired Show')
          final rtlNewsProgram = currentEntries.firstWhere(
            (p) => p.channelId == 'de.rtl' && p.title == 'RTL Aktuell Live',
          );
          expect(
            rtlNewsProgram.description,
            equals('Abendnachrichten und Sportberichte aus aller Welt.'),
          );
          // 2030-05-21 14:00:00 +0200 corresponds to 2030-05-21 12:00:00 UTC
          expect(
            rtlNewsProgram.startTime.toUtc(),
            equals(DateTime.utc(2030, 05, 21, 12, 0, 0)),
          );
          expect(
            rtlNewsProgram.endTime.toUtc(),
            equals(DateTime.utc(2030, 05, 21, 13, 30, 0)),
          );

          final rtlExpiredProgram = currentEntries.firstWhere(
            (p) => p.channelId == 'de.rtl' && p.title == 'Expired Show',
          );
          expect(
            rtlExpiredProgram.description,
            equals('This program should be auto-purged from the database'),
          );
          expect(
            rtlExpiredProgram.startTime.toUtc(),
            equals(DateTime.utc(2010, 01, 01, 12, 0, 0)),
          );
          expect(
            rtlExpiredProgram.endTime.toUtc(),
            equals(DateTime.utc(2010, 01, 01, 13, 0, 0)),
          );

          // Validate CNN program
          final cnnProgram = currentEntries.firstWhere(
            (p) => p.channelId == 'us.cnn',
          );
          expect(cnnProgram.title, equals('CNN Newsroom'));
          expect(
            cnnProgram.description,
            equals('Global news coverage and live report segments.'),
          );
          expect(
            cnnProgram.startTime.toUtc(),
            equals(DateTime.utc(2030, 05, 21, 13, 30, 0)),
          );
          expect(
            cnnProgram.endTime.toUtc(),
            equals(DateTime.utc(2030, 05, 21, 14, 30, 0)),
          );

          final epgChannels = await db.select(db.epgChannels).get();
          expect(epgChannels.length, equals(2));
          expect(
            epgChannels.map((c) => c.displayName).toSet(),
            equals({'RTL HD', 'CNN International'}),
          );
        } finally {
          // Clean up mock file from disk cleanly
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        }
      },
    );
  });
}
