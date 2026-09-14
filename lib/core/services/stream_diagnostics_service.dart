import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';

/// Lightweight HTTP probe for stream diagnostics and classification.
abstract final class StreamDiagnosticsService {
  static Future<StreamConnectionProbeResult> probeStreamUrl(
    String url, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final requestedUri = Uri.parse(url);
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = timeout;

    try {
      final headResult = await _probe(
        client: client,
        method: 'HEAD',
        uri: requestedUri,
        headers: headers,
        budget: timeout,
        stopwatch: stopwatch,
        maxRedirects: 5,
        readBodyBytes: 0,
        addRangeHeader: false,
      );

      final needsManifestRead =
          (requestedUri.path.toLowerCase().endsWith('.m3u8') ||
              headResult.looksLikeHls) &&
          headResult.bodySample == null;

      if (_shouldFallbackToGet(headResult) || needsManifestRead) {
        final getResult = await _probe(
          client: client,
          method: 'GET',
          uri: headResult.resolvedUri,
          headers: headers,
          budget: timeout,
          stopwatch: stopwatch,
          maxRedirects: 5,
          readBodyBytes: 1024,
          addRangeHeader: true,
        );
        return getResult.copyWith(
          duration: stopwatch.elapsed,
          redirectChain: [
            ...headResult.redirectChain,
            ...getResult.redirectChain,
          ],
        );
      }

      return headResult.copyWithDuration(stopwatch.elapsed);
    } on TimeoutException {
      return StreamConnectionProbeResult(
        requestedUri: requestedUri,
        resolvedUri: requestedUri,
        duration: stopwatch.elapsed,
        redirectChain: const [],
        usedHead: true,
        usedRange: false,
        timedOut: true,
      );
    } finally {
      client.close(force: true);
    }
  }

  static bool _shouldFallbackToGet(StreamConnectionProbeResult result) {
    final status = result.httpStatus;
    if (result.timedOut) return false;
    if (status == null) return true;
    return status == HttpStatus.methodNotAllowed ||
        status == HttpStatus.notImplemented;
  }

  static Future<StreamConnectionProbeResult> _probe({
    required HttpClient client,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Duration budget,
    required Stopwatch stopwatch,
    required int maxRedirects,
    required int readBodyBytes,
    required bool addRangeHeader,
  }) async {
    var current = uri;
    final redirects = <Uri>[];
    final started = DateTime.now();
    int? lastStatus;

    for (var i = 0; i <= maxRedirects; i++) {
      final request = await _withinBudget(
        stopwatch: stopwatch,
        budget: budget,
        operation: () => client.openUrl(method, current),
      );
      request.followRedirects = false;
      request.maxRedirects = 0;
      headers.forEach(request.headers.set);
      if (addRangeHeader && method == 'GET') {
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=0-${readBodyBytes - 1}',
        );
      }

      final response = await _withinBudget(
        stopwatch: stopwatch,
        budget: budget,
        operation: request.close,
      );
      final status = response.statusCode;
      lastStatus = status;
      final resolvedUri = response.redirects.isNotEmpty
          ? response.redirects.last.location
          : current;
      final redirectChain = [
        ...redirects,
        for (final redirect in response.redirects) redirect.location,
      ];

      if (_isRedirect(status)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || location.isEmpty) {
          await _withinBudget(
            stopwatch: stopwatch,
            budget: budget,
            operation: response.drain,
          );
          return StreamConnectionProbeResult(
            requestedUri: uri,
            resolvedUri: resolvedUri,
            duration: DateTime.now().difference(started),
            redirectChain: List.unmodifiable(redirectChain),
            usedHead: method == 'HEAD',
            usedRange: addRangeHeader,
            httpStatus: status,
          );
        }

        current = current.resolve(location);
        redirects.add(current);
        await _withinBudget(
          stopwatch: stopwatch,
          budget: budget,
          operation: response.drain,
        );
        continue;
      }

      final contentType = response.headers.value(HttpHeaders.contentTypeHeader);
      final bodySample = readBodyBytes <= 0
          ? null
          : await _withinBudget(
              stopwatch: stopwatch,
              budget: budget,
              operation: () =>
                  _readBodySample(response, maxBytes: readBodyBytes),
            );
      final hints = _extractHlsManifestHints(bodySample);

      return StreamConnectionProbeResult(
        requestedUri: uri,
        resolvedUri: resolvedUri,
        duration: DateTime.now().difference(started),
        redirectChain: List.unmodifiable(redirectChain),
        usedHead: method == 'HEAD',
        usedRange: addRangeHeader,
        httpStatus: status,
        contentType: contentType,
        bodySample: bodySample,
        hlsAudioRenditions: hints.audioRenditions,
        hlsCodecs: hints.codecs,
      );
    }

    return StreamConnectionProbeResult(
      requestedUri: uri,
      resolvedUri: current,
      duration: DateTime.now().difference(started),
      redirectChain: List.unmodifiable(redirects),
      usedHead: method == 'HEAD',
      usedRange: addRangeHeader,
      redirectLimitExceeded: redirects.isNotEmpty,
      httpStatus: lastStatus,
    );
  }

  static Future<T> _withinBudget<T>({
    required Stopwatch stopwatch,
    required Duration budget,
    required Future<T> Function() operation,
  }) {
    final remaining = budget - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Stream probe budget exhausted');
    }
    return operation().timeout(remaining);
  }

  static bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  static Future<String?> _readBodySample(
    HttpClientResponse response, {
    required int maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (builder.length >= maxBytes) break;
      final remaining = maxBytes - builder.length;
      if (chunk.length <= remaining) {
        builder.add(chunk);
      } else {
        builder.add(Uint8List.fromList(chunk.sublist(0, remaining)));
      }
    }

    if (builder.length == 0) return null;
    return String.fromCharCodes(builder.takeBytes());
  }

  static _HlsManifestHints _extractHlsManifestHints(String? bodySample) {
    if (bodySample == null || bodySample.isEmpty) {
      return const _HlsManifestHints();
    }

    final audioRenditions = <String>[];
    final codecs = <String>{};
    for (final rawLine in bodySample.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-MEDIA:')) {
        final attributes = _parseHlsAttributes(
          line.substring('#EXT-X-MEDIA:'.length),
        );
        if ((attributes['TYPE'] ?? '').toUpperCase() == 'AUDIO') {
          audioRenditions.add(_summarizeAudioRendition(attributes));
        }
        continue;
      }

      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attributes = _parseHlsAttributes(
          line.substring('#EXT-X-STREAM-INF:'.length),
        );
        final codecAttr = attributes['CODECS'];
        if (codecAttr != null) {
          for (final codec in codecAttr.split(',')) {
            final normalized = _friendlyHlsCodec(codec);
            if (normalized.isNotEmpty) codecs.add(normalized);
          }
        }
      }
    }

    return _HlsManifestHints(
      audioRenditions: List.unmodifiable(audioRenditions),
      codecs: List.unmodifiable(codecs),
    );
  }

  static Map<String, String> _parseHlsAttributes(String raw) {
    final attributes = <String, String>{};
    final matches = RegExp(
      r'([A-Z0-9-]+)=("([^"]*)"|[^,]*)',
      caseSensitive: false,
    ).allMatches(raw);

    for (final match in matches) {
      final key = match.group(1)?.toUpperCase();
      if (key == null || key.isEmpty) continue;

      final quotedValue = match.group(3);
      final unquotedValue = match.group(2);
      final value = (quotedValue ?? unquotedValue ?? '').trim().replaceAll(
        '"',
        '',
      );
      attributes[key] = value;
    }

    return attributes;
  }

  static String _friendlyHlsCodec(String codec) {
    final normalized = codec.trim().toLowerCase();
    if (normalized.isEmpty) return normalized;

    return switch (normalized) {
      'aac' || 'mp4a' || 'mp4a.40.2' => 'AAC',
      'ac3' || 'ac-3' => 'AC-3',
      'eac3' || 'ec-3' || 'e-ac-3' => 'E-AC-3',
      'mp2' => 'MP2',
      'mp3' => 'MP3',
      'opus' => 'Opus',
      _ => normalized.toUpperCase(),
    };
  }

  static String _summarizeAudioRendition(Map<String, String> attributes) {
    final parts = <String>[];
    for (final key in const [
      'NAME',
      'LANGUAGE',
      'GROUP-ID',
      'DEFAULT',
      'AUTOSELECT',
    ]) {
      final value = attributes[key];
      if (value != null && value.isNotEmpty) {
        parts.add('${key.toLowerCase()}=$value');
      }
    }
    return parts.isEmpty ? 'audio' : parts.join(', ');
  }

  static StreamFailureClassification classifyFailure({
    StreamConnectionProbeResult? probe,
    Object? error,
    String? mpvError,
  }) {
    final errorText = '${error ?? ''} ${mpvError ?? ''}'.toLowerCase();

    if (probe?.redirectLimitExceeded == true) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.redirectIssue,
        possible: true,
        reason: 'Redirect limit exceeded before the stream body was reached.',
      );
    }

    if (errorText.contains('timeout') ||
        error is TimeoutException ||
        probe?.timedOut == true) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.timeout,
        possible: false,
        reason: 'Connection timed out.',
      );
    }

    if (error is SocketException ||
        errorText.contains('socketexception') ||
        errorText.contains('connection refused')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.offline,
        possible: false,
        reason: 'Host unreachable or connection refused.',
      );
    }

    final status = probe?.httpStatus;
    final body = probe?.bodySample?.toLowerCase() ?? '';
    if (status == HttpStatus.unauthorized ||
        errorText.contains('unauthorized')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.unauthorized,
        possible: false,
        reason: 'HTTP 401 unauthorized.',
      );
    }
    if (status == HttpStatus.forbidden || errorText.contains('forbidden')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.forbidden,
        possible: false,
        reason: 'HTTP 403 forbidden.',
      );
    }
    if (status == HttpStatus.notFound || errorText.contains('404')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.notFound,
        possible: false,
        reason: 'HTTP 404 not found.',
      );
    }
    if (status == 451 ||
        body.contains('blocked') ||
        body.contains('forbidden') ||
        body.contains('geo')) {
      return StreamFailureClassification(
        kind: StreamingFailureKind.providerBlocked,
        possible: body.contains('blocked') || body.contains('geo'),
        reason: 'Provider access appears blocked.',
      );
    }
    if (body.contains('token') ||
        body.contains('expired') ||
        body.contains('session')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.tokenExpired,
        possible: true,
        reason: 'Token or session appears expired.',
      );
    }
    if ((probe?.resolvedUri.path.toLowerCase().endsWith('.m3u8') ?? false) &&
        probe?.bodySample != null &&
        !probe!.bodySample!.contains('#EXTM3U')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.invalidHls,
        possible: true,
        reason: 'M3U8 response did not look like a valid HLS manifest.',
      );
    }
    if (probe?.redirected == true && status != null && _isRedirect(status)) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.redirectIssue,
        possible: true,
        reason: 'Redirect chain did not resolve cleanly.',
      );
    }
    if (errorText.contains('codec') ||
        errorText.contains('format not supported') ||
        errorText.contains('unsupported')) {
      return const StreamFailureClassification(
        kind: StreamingFailureKind.unsupportedCodec,
        possible: false,
        reason: 'Player reported an unsupported codec or format.',
      );
    }

    return const StreamFailureClassification(
      kind: StreamingFailureKind.unknown,
      possible: true,
      reason: 'No clear failure signature detected.',
    );
  }
}

class _HlsManifestHints {
  const _HlsManifestHints({
    this.audioRenditions = const [],
    this.codecs = const [],
  });

  final List<String> audioRenditions;
  final List<String> codecs;
}
