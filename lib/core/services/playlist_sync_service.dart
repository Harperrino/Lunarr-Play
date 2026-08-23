import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:m3uxtream_player/core/api/xtream_client.dart';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/imports/import_cancellation.dart';
import 'package:m3uxtream_player/core/imports/import_limits.dart';
import 'package:m3uxtream_player/core/imports/import_profiles.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';

/// Service responsible for orchestrating background playlist parsing
/// and database synchronization workflows using Dart Isolates.
class PlaylistSyncService {
  final PlaylistRepository _repository;
  final Map<int, Future<void>> _inFlightSyncs = {};
  final Map<int, ImportCancellation> _inFlightCancellations = {};
  final ImportLimits _m3uLimits;
  final ImportLimits _xtreamLimits;

  PlaylistSyncService(
    this._repository, {
    this._m3uLimits = ImportProfiles.m3u,
    this._xtreamLimits = ImportProfiles.xtream,
  });

  void cancelSync(int playlistId) {
    _inFlightCancellations[playlistId]?.cancel();
  }

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
        _inFlightCancellations.remove(playlistId);
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
        final cancellation = ImportCancellation();
        _inFlightCancellations[playlistId] = cancellation;
        final budget = ImportBudget(
          limits: _m3uLimits,
          cancellation: cancellation,
        );
        final m3uContent = await _fetchM3uContent(
          playlist.urlOrHost,
          budget: budget,
        );
        await syncM3uPlaylist(
          playlistId: playlistId,
          m3uContent: m3uContent,
          budget: budget,
          inputCounted: true,
        );
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
        final cancellation = ImportCancellation();
        _inFlightCancellations[playlistId] = cancellation;
        final budget = ImportBudget(
          limits: _xtreamLimits,
          cancellation: cancellation,
        );

        final [
          liveCategoriesJson,
          liveStreamsJson,
          vodCategoriesJson,
          vodStreamsJson,
          seriesCategoriesJson,
          seriesJson,
        ] = await _runControlled<String>(
          [
            () => XtreamClient.fetchLiveCategories(
              host: credentials.host,
              username: credentials.username,
              password: credentials.password,
              budget: budget,
            ),
            () => XtreamClient.fetchLiveStreams(
              host: credentials.host,
              username: credentials.username,
              password: credentials.password,
              budget: budget,
            ),
            () => XtreamClient.fetchVodCategories(
              host: credentials.host,
              username: credentials.username,
              password: credentials.password,
              budget: budget,
            ),
            () => XtreamClient.fetchVodStreams(
              host: credentials.host,
              username: credentials.username,
              password: credentials.password,
              budget: budget,
            ),
            () => XtreamClient.fetchSeriesCategories(
              host: credentials.host,
              username: credentials.username,
              password: credentials.password,
              budget: budget,
            ),
            () => XtreamClient.fetchSeries(
              host: credentials.host,
              username: credentials.username,
              password: credentials.password,
              budget: budget,
            ),
          ],
          cancellation: cancellation,
          concurrency: 2,
        );

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
          budget: budget,
          inputCounted: true,
        );
      default:
        throw UnsupportedError(
          'PlaylistSyncService: Unsupported playlist type "${playlist.type}".',
        );
    }
  }

  /// Fetches raw M3U content from an HTTP(S) URL or local file path.
  Future<String> _fetchM3uContent(
    String urlOrHost, {
    required ImportBudget budget,
  }) async {
    if (urlOrHost.startsWith('http://') || urlOrHost.startsWith('https://')) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final unregisterCancellation = budget.cancellation.register(
        () => client.close(force: true),
      );
      try {
        final request = await client.getUrl(Uri.parse(urlOrHost));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'M3U fetch failed with HTTP ${response.statusCode}.',
          );
        }
        return await _readBudgetedUtf8(
          response,
          budget: budget,
          transportPhase: 'm3u_transport',
          decodePhase: 'm3u_decode',
        );
      } finally {
        unregisterCancellation();
        client.close();
      }
    }

    final file = File(urlOrHost);
    if (await file.exists()) {
      return _readBudgetedUtf8(
        file.openRead(),
        budget: budget,
        transportPhase: 'm3u_transport',
        decodePhase: 'm3u_decode',
      );
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
    ImportBudget? budget,
    bool inputCounted = false,
  }) async {
    final importBudget = budget ?? ImportBudget(limits: _m3uLimits);
    if (!inputCounted) {
      importBudget.consumeDecodedBytes(
        utf8.encode(m3uContent).length,
        phase: 'm3u_decode',
      );
    }
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'PlaylistSyncService: Commencing sync cycle for Playlist ID: $playlistId. Spawning parser Isolate...',
    );

    try {
      final List<ParsedChannel> parsedChannels = await _runM3uParserIsolate(
        m3uContent,
        importBudget,
      );
      importBudget.acceptRecord(
        ImportRecordKind.channel,
        count: parsedChannels.length,
        phase: 'm3u_parse_records',
      );
      importBudget.checkpoint('m3u_persist');

      AppLogger.info(
        'PlaylistSyncService: Parsing Isolate complete. Extracted ${parsedChannels.length} channels. Invoking database batch-sync...',
      );

      await _repository.syncM3uChannels(
        playlistId: playlistId,
        parsedChannels: parsedChannels,
        budget: importBudget,
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
    ImportBudget? budget,
    bool inputCounted = false,
  }) async {
    final importBudget = budget ?? ImportBudget(limits: _xtreamLimits);
    if (!inputCounted) {
      for (final payload in <String>[
        liveStreamsJson,
        liveCategoriesJson,
        vodStreamsJson,
        vodCategoriesJson,
        seriesJson,
        seriesCategoriesJson,
      ]) {
        importBudget.consumeDecodedBytes(
          utf8.encode(payload).length,
          phase: 'xtream_decode',
        );
      }
    }
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

      final List<ParsedChannel> parsedChannels = await _runXtreamParserIsolate(
        payload,
        importBudget,
      );
      importBudget.acceptRecord(
        ImportRecordKind.channel,
        count: parsedChannels.length,
        phase: 'xtream_parse_records',
      );
      importBudget.checkpoint('xtream_persist');

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
        budget: importBudget,
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

  Future<List<T>> _runControlled<T>(
    List<Future<T> Function()> tasks, {
    required ImportCancellation cancellation,
    required int concurrency,
  }) async {
    final results = List<T?>.filled(tasks.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        cancellation.throwIfCancelled();
        if (nextIndex >= tasks.length) return;
        final index = nextIndex++;
        results[index] = await tasks[index]();
      }
    }

    try {
      await Future.wait(
        List.generate(concurrency.clamp(1, tasks.length), (_) => worker()),
        eagerError: true,
      );
      cancellation.throwIfCancelled();
      return results.cast<T>();
    } catch (error) {
      cancellation.cancel(error);
      rethrow;
    }
  }

  Future<List<ParsedChannel>> _runM3uParserIsolate(
    String content,
    ImportBudget budget,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _m3uImportIsolateEntry,
      _M3uImportIsolateRequest(
        sendPort: receivePort.sendPort,
        content: content,
        limits: budget.limits,
        startedAt: budget.startedAt,
      ),
    );
    return _awaitParserIsolate(isolate, receivePort, budget);
  }

  Future<List<ParsedChannel>> _runXtreamParserIsolate(
    XtreamCataloguePayload payload,
    ImportBudget budget,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _xtreamImportIsolateEntry,
      _XtreamImportIsolateRequest(
        sendPort: receivePort.sendPort,
        payload: payload,
        limits: budget.limits,
        startedAt: budget.startedAt,
      ),
    );
    return _awaitParserIsolate(isolate, receivePort, budget);
  }

  Future<List<ParsedChannel>> _awaitParserIsolate(
    Isolate isolate,
    ReceivePort receivePort,
    ImportBudget budget,
  ) async {
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
      if (message is _PlaylistImportIsolateSuccess) {
        return message.channels;
      }
      if (message is _PlaylistImportIsolateFailure) {
        Error.throwWithStackTrace(
          message.error,
          StackTrace.fromString(message.stackTrace),
        );
      }
      throw const FormatException(
        'Playlist import worker returned invalid data.',
      );
    } finally {
      unregisterCancellation();
      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  Future<String> _readBudgetedUtf8(
    Stream<List<int>> source, {
    required ImportBudget budget,
    required String transportPhase,
    required String decodePhase,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in source) {
      budget.consumeTransportBytes(chunk.length, phase: transportPhase);
      budget.consumeDecodedBytes(chunk.length, phase: decodePhase);
      bytes.add(chunk);
    }
    budget.checkpoint(decodePhase);
    return utf8.decode(bytes.takeBytes());
  }
}

class _M3uImportIsolateRequest {
  final SendPort sendPort;
  final String content;
  final ImportLimits limits;
  final DateTime startedAt;

  const _M3uImportIsolateRequest({
    required this.sendPort,
    required this.content,
    required this.limits,
    required this.startedAt,
  });
}

class _XtreamImportIsolateRequest {
  final SendPort sendPort;
  final XtreamCataloguePayload payload;
  final ImportLimits limits;
  final DateTime startedAt;

  const _XtreamImportIsolateRequest({
    required this.sendPort,
    required this.payload,
    required this.limits,
    required this.startedAt,
  });
}

class _PlaylistImportIsolateSuccess {
  final List<ParsedChannel> channels;
  const _PlaylistImportIsolateSuccess(this.channels);
}

class _PlaylistImportIsolateFailure {
  final Object error;
  final String stackTrace;
  const _PlaylistImportIsolateFailure(this.error, this.stackTrace);
}

Future<void> _m3uImportIsolateEntry(_M3uImportIsolateRequest request) async {
  try {
    final budget = ImportBudget(
      limits: request.limits,
      startedAt: request.startedAt,
    );
    final channels = M3uParser.parse(request.content, budget: budget);
    request.sendPort.send(_PlaylistImportIsolateSuccess(channels));
  } catch (error, stackTrace) {
    request.sendPort.send(
      _PlaylistImportIsolateFailure(error, stackTrace.toString()),
    );
  }
}

Future<void> _xtreamImportIsolateEntry(
  _XtreamImportIsolateRequest request,
) async {
  try {
    final budget = ImportBudget(
      limits: request.limits,
      startedAt: request.startedAt,
    );
    final channels = XtreamParser.parseFullCatalogue(
      request.payload,
      budget: budget,
    );
    request.sendPort.send(_PlaylistImportIsolateSuccess(channels));
  } catch (error, stackTrace) {
    request.sendPort.send(
      _PlaylistImportIsolateFailure(error, stackTrace.toString()),
    );
  }
}
