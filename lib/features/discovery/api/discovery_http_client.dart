import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';

class DiscoveryHttpResponse {
  const DiscoveryHttpResponse({required this.statusCode, required this.json});

  final int statusCode;
  final Object? json;
}

/// Bounded JSON transport with one absolute deadline covering send and body.
class DiscoveryHttpClient {
  DiscoveryHttpClient(
    this._client, {
    this.timeout = const Duration(seconds: 12),
    this.maxJsonBytes = 2 * 1024 * 1024,
  });

  final http.Client _client;
  final Duration timeout;
  final int maxJsonBytes;

  Future<DiscoveryHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
  }) => _send('GET', uri, headers: headers);

  Future<DiscoveryHttpResponse> post(
    Uri uri, {
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) => _send('POST', uri, headers: headers, body: body);

  Future<DiscoveryHttpResponse> _send(
    String method,
    Uri initialUri, {
    required Map<String, String> headers,
    Object? body,
  }) async {
    final startedAt = DateTime.now();
    var uri = initialUri;
    for (var redirectCount = 0; redirectCount <= 3; redirectCount++) {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll(<String, String>{
          'Accept': 'application/json',
          ...headers,
        });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }

      final remaining = timeout - DateTime.now().difference(startedAt);
      if (remaining <= Duration.zero) {
        throw const DiscoveryApiException(DiscoveryFailureKind.timeout);
      }

      http.StreamedResponse response;
      try {
        response = await _client.send(request).timeout(remaining);
      } on TimeoutException {
        throw const DiscoveryApiException(DiscoveryFailureKind.timeout);
      } on DiscoveryApiException {
        rethrow;
      } catch (_) {
        throw const DiscoveryApiException(DiscoveryFailureKind.network);
      }

      final bytes = await _readBody(
        response.stream,
        timeout - DateTime.now().difference(startedAt),
      );
      if (_isRedirect(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null || redirectCount == 3) {
          throw DiscoveryApiException(
            DiscoveryFailureKind.invalidResponse,
            statusCode: response.statusCode,
          );
        }
        final redirected = uri.resolve(location);
        if (!_sameOrigin(initialUri, redirected)) {
          throw const DiscoveryApiException(
            DiscoveryFailureKind.invalidEndpoint,
          );
        }
        uri = redirected;
        continue;
      }

      Object? decoded;
      if (bytes.isNotEmpty) {
        try {
          decoded = jsonDecode(utf8.decode(bytes));
        } catch (_) {
          throw DiscoveryApiException(
            DiscoveryFailureKind.invalidResponse,
            statusCode: response.statusCode,
          );
        }
      }
      return DiscoveryHttpResponse(
        statusCode: response.statusCode,
        json: decoded,
      );
    }
    throw const DiscoveryApiException(DiscoveryFailureKind.invalidResponse);
  }

  Future<Uint8List> _readBody(
    Stream<List<int>> stream,
    Duration remaining,
  ) async {
    if (remaining <= Duration.zero) {
      throw const DiscoveryApiException(DiscoveryFailureKind.timeout);
    }
    final builder = BytesBuilder(copy: false);
    final completer = Completer<Uint8List>();
    late StreamSubscription<List<int>> subscription;
    Timer? timer;
    subscription = stream.listen(
      (chunk) {
        if (builder.length + chunk.length > maxJsonBytes) {
          unawaited(subscription.cancel());
          if (!completer.isCompleted) {
            completer.completeError(
              const DiscoveryApiException(
                DiscoveryFailureKind.responseTooLarge,
              ),
            );
          }
          return;
        }
        builder.add(chunk);
      },
      onError: (Object _) {
        if (!completer.isCompleted) {
          completer.completeError(
            const DiscoveryApiException(DiscoveryFailureKind.network),
          );
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(builder.takeBytes());
      },
      cancelOnError: true,
    );
    timer = Timer(remaining, () {
      unawaited(subscription.cancel());
      if (!completer.isCompleted) {
        completer.completeError(
          const DiscoveryApiException(DiscoveryFailureKind.timeout),
        );
      }
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  bool _isRedirect(int status) => status >= 300 && status < 400;

  bool _sameOrigin(Uri original, Uri redirected) =>
      original.scheme.toLowerCase() == redirected.scheme.toLowerCase() &&
      original.host.toLowerCase() == redirected.host.toLowerCase() &&
      original.port == redirected.port;
}
