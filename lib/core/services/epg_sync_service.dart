import 'dart:io';
import 'dart:isolate';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/imports/import_cancellation.dart';
import 'package:m3uxtream_player/core/imports/import_limits.dart';
import 'package:m3uxtream_player/core/imports/import_profiles.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/models/playlist_epg.dart';
import 'package:m3uxtream_player/core/parsers/epg_parser.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';

/// Service responsible for orchestrating background EPG / XMLTV downloading,
/// GZIP decompression, streaming XML parsing, and Drift SQLite caching.
class EpgSyncService {
  final EpgRepository _epgRepository;
  final PlaylistRepository _playlistRepository;
  final ImportLimits _xmltvLimits;
  final Map<int, ImportCancellation> _inFlightCancellations = {};

  EpgSyncService(
    this._epgRepository,
    this._playlistRepository, {
    this._xmltvLimits = ImportProfiles.xmltv,
  });

  void cancelSync(int playlistId) {
    _inFlightCancellations[playlistId]?.cancel();
  }

  /// Synchronizes EPG for a playlist using its effective override/automatic URL.
  Future<void> syncEpgForPlaylist(int playlistId) async {
    final playlist = await _playlistRepository.getPlaylistById(playlistId);
    if (playlist == null) {
      throw StateError('EpgSyncService: Playlist ID $playlistId not found.');
    }

    final epgUrl = playlist.effectiveEpgUrl;
    if (epgUrl == null || epgUrl.isEmpty) {
      throw StateError(
        'EpgSyncService: Playlist "${playlist.name}" has no EPG URL configured.',
      );
    }

    await syncEpg(playlistId: playlistId, urlOrFilePath: epgUrl);
    await _playlistRepository.updateEpgLastSyncedAt(playlistId, DateTime.now());
  }

  /// Synchronizes EPG program guides from a remote Web URL or local file path.
  ///
  /// - Spawns a dedicated background Dart Isolate (`Isolate.run`) to handle network
  ///   streaming, file IO, GZIP decompression, and event XML-parsing.
  /// - On the main thread, purges all outdated/expired program guides (endTime in the past).
  /// - Clears existing entries for affected channel IDs before inserting fresh data.
  /// - Synchronizes the fresh entries in Drift SQLite using highly-optimized 1,000-row batches.
  Future<void> syncEpg({
    required int playlistId,
    required String urlOrFilePath,
  }) async {
    final stopwatch = Stopwatch()..start();
    final cancellation = ImportCancellation();
    _inFlightCancellations[playlistId] = cancellation;
    final budget = ImportBudget(
      limits: _xmltvLimits,
      cancellation: cancellation,
    );
    final sourceType =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(urlOrFilePath)
        ? 'network'
        : 'local';
    AppLogger.info(
      'EpgSyncService: Initiating EPG sync workflow (source: $sourceType).',
    );

    try {
      // 1. Spawns an isolated worker thread to perform download, GZIP decompression,
      // and streaming event parsing, keeping the main UI thread at absolute 120Hz.
      final EpgParseResult parseResult = await _runEpgImportIsolate(
        urlOrFilePath,
        budget: budget,
      );

      final parsedEntries = parseResult.entries;
      final parsedChannels = parseResult.channels;
      budget.acceptRecord(
        ImportRecordKind.record,
        count: parsedEntries.length,
        phase: 'xmltv_parse_programmes',
      );
      budget.acceptRecord(
        ImportRecordKind.channel,
        count: parsedChannels.length,
        phase: 'xmltv_parse_channels',
      );
      budget.checkpoint('xmltv_persist');

      AppLogger.info(
        'EpgSyncService: Isolate completed. Extracted ${parsedEntries.length} program guides '
        'and ${parsedChannels.length} channel names. Starting database writes...',
      );

      budget.acceptPersistedRows(
        parsedEntries.length + parsedChannels.length,
        phase: 'xmltv_persist',
      );
      // Preserve the established behavior: purge rows that were stale before
      // the import, while retaining historical programmes present in XMLTV.
      await _epgRepository.purgeOutdatedEpgData();

      // Replace both cache tables as one transaction. Every limit has already
      // been validated before the first mutation.
      await _epgRepository.replaceImportedEpgData(
        playlistId: playlistId,
        entries: parsedEntries,
        channels: parsedChannels,
        budget: budget,
        rowsCounted: true,
      );

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
    } finally {
      if (identical(_inFlightCancellations[playlistId], cancellation)) {
        _inFlightCancellations.remove(playlistId);
      }
    }
  }

  Future<EpgParseResult> _runEpgImportIsolate(
    String source, {
    required ImportBudget budget,
  }) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _epgImportIsolateEntry,
      _EpgImportIsolateRequest(
        sendPort: receivePort.sendPort,
        source: source,
        limits: budget.limits,
        startedAt: budget.startedAt,
      ),
    );
    final unregisterCancellation = budget.cancellation.register(
      () => isolate.kill(priority: Isolate.immediate),
    );

    try {
      final message = await Future.any<Object?>([
        receivePort.first,
        budget.cancellation.whenCancelled.then<Object?>((_) {
          budget.cancellation.throwIfCancelled();
          return null;
        }),
      ]);
      if (message is _EpgImportIsolateSuccess) {
        return message.result;
      }
      if (message is _EpgImportIsolateFailure) {
        Error.throwWithStackTrace(
          message.error,
          StackTrace.fromString(message.stackTrace),
        );
      }
      throw const FormatException('EPG import worker returned invalid data.');
    } finally {
      unregisterCancellation();
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }
}

/// Top-level isolate entry — downloads/parses EPG with GZIP auto-detection.
Future<EpgParseResult> _downloadAndParseInIsolate(
  String urlOrFilePath,
  ImportBudget budget,
) async {
  Stream<List<int>> byteStream;
  HttpClient? client;
  void Function()? unregisterCancellation;
  var isGzipped = urlOrFilePath.toLowerCase().endsWith('.gz');

  if (RegExp(
    r'^https?://',
    caseSensitive: false,
  ).hasMatch(urlOrFilePath)) {
    AppLogger.info(
      'EpgSyncService (Isolate): Direct streaming EPG from remote HTTP URL...',
    );
    client = HttpClient();
    unregisterCancellation = budget.cancellation.register(
      () => client?.close(force: true),
    );
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
    final budgetedTransport = byteStream.map((chunk) {
      budget.consumeTransportBytes(chunk.length, phase: 'xmltv_transport');
      return chunk;
    });
    return await EpgParser.parse(
      byteStream: budgetedTransport,
      isGzipped: isGzipped,
      budget: budget,
    );
  } finally {
    unregisterCancellation?.call();
    client?.close();
  }
}

class _EpgImportIsolateRequest {
  final SendPort sendPort;
  final String source;
  final ImportLimits limits;
  final DateTime startedAt;

  const _EpgImportIsolateRequest({
    required this.sendPort,
    required this.source,
    required this.limits,
    required this.startedAt,
  });
}

class _EpgImportIsolateSuccess {
  final EpgParseResult result;
  const _EpgImportIsolateSuccess(this.result);
}

class _EpgImportIsolateFailure {
  final Object error;
  final String stackTrace;
  const _EpgImportIsolateFailure(this.error, this.stackTrace);
}

Future<void> _epgImportIsolateEntry(_EpgImportIsolateRequest request) async {
  try {
    final budget = ImportBudget(
      limits: request.limits,
      startedAt: request.startedAt,
    );
    final result = await _downloadAndParseInIsolate(request.source, budget);
    request.sendPort.send(_EpgImportIsolateSuccess(result));
  } catch (error, stackTrace) {
    request.sendPort.send(
      _EpgImportIsolateFailure(error, stackTrace.toString()),
    );
  }
}
