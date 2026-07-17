import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:m3uxtream_player/core/api/xtream_client.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';

/// Service responsible for orchestrating background playlist parsing
/// and database synchronization workflows using Dart Isolates.
class PlaylistSyncService {
  final PlaylistRepository _repository;
  final Map<int, Future<void>> _inFlightSyncs = {};

  PlaylistSyncService(this._repository);

  /// Resolves a playlist by ID, fetches its remote/local source, and runs the
  /// full isolate-based parse + batch-insert pipeline.
  Future<void> syncPlaylist(int playlistId) async {
    final existing = _inFlightSyncs[playlistId];
    if (existing != null) {
      AppLogger.info(
        'PlaylistSyncService: Reusing in-flight sync for Playlist ID: $playlistId.',
      );
      return existing;
    }

    final future = _syncPlaylistLocked(playlistId);
    _inFlightSyncs[playlistId] = future;
    return future.whenComplete(() {
      if (identical(_inFlightSyncs[playlistId], future)) {
        _inFlightSyncs.remove(playlistId);
      }
    });
  }

  Future<void> _syncPlaylistLocked(int playlistId) async {
    final playlist = await _repository.getPlaylistById(playlistId);
    if (playlist == null) {
      throw StateError(
        'PlaylistSyncService: Playlist ID $playlistId not found.',
      );
    }

    AppLogger.info(
      'PlaylistSyncService: Starting full sync for "${playlist.name}" (type: ${playlist.type}).',
    );

    switch (playlist.type) {
      case 'm3u':
        final m3uContent = await _fetchM3uContent(playlist.urlOrHost);
        await syncM3uPlaylist(playlistId: playlistId, m3uContent: m3uContent);
      case 'xtream':
        final username = playlist.username;
        final password = playlist.password;
        if (username == null || password == null) {
          throw StateError(
            'PlaylistSyncService: Xtream playlist "${playlist.name}" is missing credentials.',
          );
        }

        final host = playlist.urlOrHost;
        final credentials = (
          host: host,
          username: username,
          password: password,
        );

        final [
          liveCategoriesJson,
          liveStreamsJson,
          vodCategoriesJson,
          vodStreamsJson,
          seriesCategoriesJson,
          seriesJson,
        ] = await Future.wait([
          XtreamClient.fetchLiveCategories(
            host: credentials.host,
            username: credentials.username,
            password: credentials.password,
          ),
          XtreamClient.fetchLiveStreams(
            host: credentials.host,
            username: credentials.username,
            password: credentials.password,
          ),
          XtreamClient.fetchVodCategories(
            host: credentials.host,
            username: credentials.username,
            password: credentials.password,
          ),
          XtreamClient.fetchVodStreams(
            host: credentials.host,
            username: credentials.username,
            password: credentials.password,
          ),
          XtreamClient.fetchSeriesCategories(
            host: credentials.host,
            username: credentials.username,
            password: credentials.password,
          ),
          XtreamClient.fetchSeries(
            host: credentials.host,
            username: credentials.username,
            password: credentials.password,
          ),
        ]);

        await syncXtreamPlaylist(
          playlistId: playlistId,
          liveStreamsJson: liveStreamsJson,
          liveCategoriesJson: liveCategoriesJson,
          vodStreamsJson: vodStreamsJson,
          vodCategoriesJson: vodCategoriesJson,
          seriesJson: seriesJson,
          seriesCategoriesJson: seriesCategoriesJson,
          host: host,
          username: username,
          password: password,
        );
      default:
        throw UnsupportedError(
          'PlaylistSyncService: Unsupported playlist type "${playlist.type}".',
        );
    }
  }

  /// Fetches raw M3U content from an HTTP(S) URL or local file path.
  Future<String> _fetchM3uContent(String urlOrHost) async {
    if (urlOrHost.startsWith('http://') || urlOrHost.startsWith('https://')) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final request = await client.getUrl(Uri.parse(urlOrHost));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'M3U fetch failed with HTTP ${response.statusCode}.',
          );
        }
        return await response.transform(utf8.decoder).join();
      } finally {
        client.close();
      }
    }

    final file = File(urlOrHost);
    if (await file.exists()) {
      return file.readAsString();
    }

    throw FormatException(
      'PlaylistSyncService: Invalid M3U source "$urlOrHost".',
    );
  }

  /// Synchronizes an M3U playlist by parsing its raw string content inside a
  /// dedicated background Isolate (worker thread) and writing it to the database.
  Future<void> syncM3uPlaylist({
    required int playlistId,
    required String m3uContent,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'PlaylistSyncService: Commencing sync cycle for Playlist ID: $playlistId. Spawning parser Isolate...',
    );

    try {
      final List<ParsedChannel> parsedChannels = await Isolate.run(() {
        return M3uParser.parse(m3uContent);
      });

      AppLogger.info(
        'PlaylistSyncService: Parsing Isolate complete. Extracted ${parsedChannels.length} channels. Invoking database batch-sync...',
      );

      await _repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: parsedChannels,
      );

      final epgUrl = M3uParser.extractEpgUrl(m3uContent);
      await _repository.setEpgUrlFromM3uHeader(playlistId, epgUrl);

      stopwatch.stop();
      AppLogger.info(
        'PlaylistSyncService: Completed full sync cycle for Playlist ID: $playlistId in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'PlaylistSyncService FATAL: Failed orchestrating sync for Playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Synchronizes an Xtream Codes playlist (live + VOD + series) via background Isolate.
  Future<void> syncXtreamPlaylist({
    required int playlistId,
    required String liveStreamsJson,
    required String liveCategoriesJson,
    String vodStreamsJson = '',
    String vodCategoriesJson = '',
    String seriesJson = '',
    String seriesCategoriesJson = '',
    required String host,
    required String username,
    required String password,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'PlaylistSyncService: Commencing Xtream sync cycle for Playlist ID: $playlistId. Spawning Isolate...',
    );

    try {
      final payload = XtreamCataloguePayload(
        liveStreamsJson: liveStreamsJson,
        liveCategoriesJson: liveCategoriesJson,
        vodStreamsJson: vodStreamsJson,
        vodCategoriesJson: vodCategoriesJson,
        seriesJson: seriesJson,
        seriesCategoriesJson: seriesCategoriesJson,
        host: host,
        username: username,
        password: password,
      );

      final List<ParsedChannel> parsedChannels = await Isolate.run(() {
        return XtreamParser.parseFullCatalogue(payload);
      });

      final liveCount = parsedChannels
          .where((c) => c.channelType == 'live')
          .length;
      final vodCount = parsedChannels
          .where((c) => c.channelType == 'vod')
          .length;
      final seriesCount = parsedChannels
          .where((c) => c.channelType == 'series')
          .length;

      AppLogger.info(
        'PlaylistSyncService: Xtream parsing complete — live: $liveCount, vod: $vodCount, series: $seriesCount. Invoking database batch-sync...',
      );

      await _repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: parsedChannels,
      );

      stopwatch.stop();
      AppLogger.info(
        'PlaylistSyncService: Completed full Xtream sync cycle for Playlist ID: $playlistId in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'PlaylistSyncService FATAL: Failed orchestrating Xtream sync for Playlist ID: $playlistId!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}
