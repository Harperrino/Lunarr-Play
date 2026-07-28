import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

/// Highly-optimized API Client for communicating with IPTV Xtream Codes servers.
/// Uses native 'dart:io' HttpClient to ensure minimal footprint and complete
/// package independence (no dio/http dependency).
class XtreamClient {
  /// Normalizes the host URL by trimming, removing trailing slashes,
  /// and prepending 'http://' if no protocol scheme is defined.
  static String normalizeHost(String host) {
    var url = host.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Base helper to perform HTTP GET requests to the Xtream API.
  /// Returns the raw response body as a String to allow background Isolate parsing.
  static Future<String> _requestRaw({
    required String host,
    required String username,
    required String password,
    String? action,
    Map<String, String> extraParams = const {},
    ImportBudget? budget,
    String endpoint = 'xtream',
  }) async {
    budget?.checkpoint('xtream_transport');
    final baseUrl = normalizeHost(host);
    if (baseUrl.isEmpty) {
      throw const FormatException('XtreamClient: Host URL cannot be empty.');
    }

    final query = <String, String>{
      'username': username,
      'password': password,
      'action': ?action,
      ...extraParams,
    };

    final fullUrl = Uri.parse(
      '$baseUrl/player_api.php',
    ).replace(queryParameters: query).toString();
    AppLogger.info(
      'XtreamClient: GET request initiated (Action: ${action ?? "auth"}).',
    );

    final client = HttpClient();
    // Prevent UI freezes by setting tight connection timeouts (12 seconds)
    client.connectionTimeout = const Duration(seconds: 12);
    final unregisterCancellation = budget?.cancellation.register(
      () => client.close(force: true),
    );

    try {
      final uri = Uri.parse(fullUrl);
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Xtream API returned invalid HTTP Status Code: ${response.statusCode}',
        );
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        budget?.consumeTransportBytes(
          chunk.length,
          phase: 'xtream_transport',
          endpoint: endpoint,
        );
        budget?.consumeDecodedBytes(
          chunk.length,
          phase: 'xtream_decode',
        );
        bytes.add(chunk);
      }
      budget?.checkpoint('xtream_decode');
      return utf8.decode(bytes.takeBytes());
    } catch (e, stackTrace) {
      AppLogger.error(
        'XtreamClient: Network request failed to execute!',
        e,
        stackTrace,
      );
      rethrow;
    } finally {
      unregisterCancellation?.call();
      client.close();
    }
  }

  /// Authenticates credentials against the Xtream Codes server.
  /// Returns decoded user_info and server_info map on success.
  static Future<Map<String, dynamic>> authenticate({
    required String host,
    required String username,
    required String password,
  }) async {
    final responseStr = await _requestRaw(
      host: host,
      username: username,
      password: password,
    );

    try {
      final decoded = jsonDecode(responseStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException(
        'Xtream Codes authentication response is not a valid JSON Object.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'XtreamClient: JSON decode of authentication payload failed!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Fetches live stream categories from the server.
  /// Returns the raw JSON String to avoid blocking the main UI thread during parsing.
  static Future<String> fetchLiveCategories({
    required String host,
    required String username,
    required String password,
    ImportBudget? budget,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_live_categories',
      budget: budget,
      endpoint: 'live_categories',
    );
  }

  /// Fetches live streams from the server.
  /// Returns the raw JSON String to offload JSON decoding into background threads.
  static Future<String> fetchLiveStreams({
    required String host,
    required String username,
    required String password,
    ImportBudget? budget,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_live_streams',
      budget: budget,
      endpoint: 'live_streams',
    );
  }

  /// Fetches VOD categories from the server.
  static Future<String> fetchVodCategories({
    required String host,
    required String username,
    required String password,
    ImportBudget? budget,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_vod_categories',
      budget: budget,
      endpoint: 'vod_categories',
    );
  }

  /// Fetches VOD streams (movies) from the server.
  static Future<String> fetchVodStreams({
    required String host,
    required String username,
    required String password,
    ImportBudget? budget,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_vod_streams',
      budget: budget,
      endpoint: 'vod_streams',
    );
  }

  /// Fetches series categories from the server.
  static Future<String> fetchSeriesCategories({
    required String host,
    required String username,
    required String password,
    ImportBudget? budget,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_series_categories',
      budget: budget,
      endpoint: 'series_categories',
    );
  }

  /// Fetches series catalogue entries from the server.
  static Future<String> fetchSeries({
    required String host,
    required String username,
    required String password,
    ImportBudget? budget,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_series',
      budget: budget,
      endpoint: 'series',
    );
  }

  /// Fetches episode metadata for a single series (lazy load — M6C UI).
  static Future<String> fetchSeriesInfo({
    required String host,
    required String username,
    required String password,
    required String seriesId,
  }) async {
    return await _requestRaw(
      host: host,
      username: username,
      password: password,
      action: 'get_series_info',
      extraParams: {'series_id': seriesId},
    );
  }
}
