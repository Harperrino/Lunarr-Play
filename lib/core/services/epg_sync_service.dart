import 'dart:io';
import 'dart:isolate';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';

/// Service responsible for orchestrating background EPG / XMLTV downloading,
/// GZIP decompression, streaming XML parsing, and Drift SQLite caching.
class EpgSyncService {
  final EpgRepository _epgRepository;
  final PlaylistRepository _playlistRepository;

  EpgSyncService(this._epgRepository, this._playlistRepository);

  /// Synchronizes EPG for a playlist using its configured [Playlist.epgUrl].
  Future<void> syncEpgForPlaylist(int playlistId) async {
    final playlist = await _playlistRepository.getPlaylistById(playlistId);
    if (playlist == null) {
      throw StateError('EpgSyncService: Playlist ID $playlistId not found.');
    }

    final epgUrl = playlist.epgUrl?.trim();
    if (epgUrl == null || epgUrl.isEmpty) {
      throw StateError(
        'EpgSyncService: Playlist "${playlist.name}" has no EPG URL configured.',
      );
    }

    await syncEpg(urlOrFilePath: epgUrl);
    await _playlistRepository.updateEpgLastSyncedAt(playlistId, DateTime.now());
  }

  /// Synchronizes EPG program guides from a remote Web URL or local file path.
  ///
  /// - Spawns a dedicated background Dart Isolate (`Isolate.run`) to handle network
  ///   streaming, file IO, GZIP decompression, and event XML-parsing.
  /// - On the main thread, purges all outdated/expired program guides (endTime in the past).
  /// - Clears existing entries for affected channel IDs before inserting fresh data.
  /// - Synchronizes the fresh entries in Drift SQLite using highly-optimized 1,000-row batches.
  Future<void> syncEpg({required String urlOrFilePath}) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'EpgSyncService: Initiating EPG sync workflow for path/url: "$urlOrFilePath"...',
    );

    try {
      // 1. Spawns an isolated worker thread to perform download, GZIP decompression,
      // and streaming event parsing, keeping the main UI thread at absolute 120Hz.
      final EpgParseResult parseResult = await Isolate.run(() async {
        return _downloadAndParseInIsolate(urlOrFilePath);
      });

      final parsedEntries = parseResult.entries;
      final parsedChannels = parseResult.channels;

      AppLogger.info(
        'EpgSyncService: Isolate completed. Extracted ${parsedEntries.length} program guides '
        'and ${parsedChannels.length} channel names. Starting database writes...',
      );

      // 2. Clear outdated entries where endTime is in the past to keep tables compact
      await _epgRepository.purgeOutdatedEpgData();

      // 3. Remove stale entries for channels present in the new payload (re-sync dedup)
      final channelIds = parsedEntries.map((e) => e.channelId).toSet().toList();
      await _epgRepository.clearEntriesForChannelIds(channelIds);

      // 4. Write new EPG guide data to Drift SQLite in transaction batches of 1,000
      await _epgRepository.syncEpgEntries(entries: parsedEntries);

      // 5. Refresh XMLTV channel catalogue (display-name → id mapping for matching)
      await _epgRepository.syncEpgChannels(channels: parsedChannels);

      stopwatch.stop();
      AppLogger.info(
        'EpgSyncService: Successfully finalized full EPG sync lifecycle in ${stopwatch.elapsedMilliseconds}ms.',
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'EpgSyncService FATAL: EPG synchronization workflow crashed!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
}

/// Top-level isolate entry — downloads/parses EPG with GZIP auto-detection.
Future<EpgParseResult> _downloadAndParseInIsolate(String urlOrFilePath) async {
  Stream<List<int>> byteStream;
  HttpClient? client;
  var isGzipped = urlOrFilePath.toLowerCase().endsWith('.gz');

  if (urlOrFilePath.startsWith('http://') ||
      urlOrFilePath.startsWith('https://')) {
    AppLogger.info(
      'EpgSyncService (Isolate): Direct streaming EPG from remote HTTP URL...',
    );
    client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final request = await client.getUrl(Uri.parse(urlOrFilePath));
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      client.close();
      throw HttpException(
        'HTTP error during EPG download: Status ${response.statusCode}',
        uri: Uri.parse(urlOrFilePath),
      );
    }

    final contentEncoding =
        response.headers.value('content-encoding')?.toLowerCase() ?? '';
    if (contentEncoding.contains('gzip')) {
      isGzipped = true;
    }

    byteStream = response;
  } else {
    AppLogger.info(
      'EpgSyncService (Isolate): Streaming EPG from local file path...',
    );
    final file = File(urlOrFilePath);
    if (!await file.exists()) {
      throw FileSystemException(
        'Local EPG XMLTV file not found at specified path.',
        urlOrFilePath,
      );
    }
    byteStream = file.openRead();
  }

  try {
    return await EpgParser.parse(byteStream: byteStream, isGzipped: isGzipped);
  } finally {
    client?.close();
  }
}
