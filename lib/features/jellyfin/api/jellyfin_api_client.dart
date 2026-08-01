import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_url_builder.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_server_info.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_log_redactor.dart';

/// Raw result of `AuthenticateByName`.
class JellyfinAuthentication {
  const JellyfinAuthentication({
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.serverId,
  });

  final String accessToken;
  final String userId;
  final String username;
  final String serverId;
}

/// Small REST client for the Jellyfin endpoints Lunarr actually uses.
///
/// The HTTP transport is injectable for tests. Logged content passes through
/// [JellyfinLogRedactor]; passwords, tokens and request bodies are never
/// logged.
class JellyfinApiClient {
  JellyfinApiClient({
    http.Client? transport,
    this._requestTimeout = const Duration(seconds: 8),
    this._urlBuilder = const JellyfinUrlBuilder(),
  }) : _transport = transport ?? http.Client();

  static const String _clientName = 'Lunarr Player';
  static const String _clientVersion = '1.0.0';

  final http.Client _transport;
  final Duration _requestTimeout;
  final JellyfinUrlBuilder _urlBuilder;
  final JellyfinLogRedactor _redactor = const JellyfinLogRedactor();

  /// Validates and normalizes a server address and fetches its public info.
  Future<JellyfinServerInfo> fetchPublicServerInfo(String inputUrl) async {
    final baseUrl = _urlBuilder.normalizeBaseUrl(inputUrl);
    AppLogger.info(
      _redactor.redact('JellyfinApiClient: Fetching public system info from $baseUrl.'),
    );

    final response = await _send(
      _urlBuilder.systemInfoPublic(baseUrl),
      method: 'GET',
      baseUrl: baseUrl,
    );

    if (response.statusCode != 200) {
      throw JellyfinApiException(
        kind: JellyfinFailureKind.notJellyfin,
        statusCode: response.statusCode,
      );
    }

    final JellyfinServerInfo server;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      server = JellyfinServerInfo.fromPublicJson(baseUrl, decoded);
      if (server.serverName.isEmpty || server.serverId.isEmpty) {
        throw const FormatException('Missing server identity fields.');
      }
    } on FormatException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.notJellyfin,
        message: 'Public system info did not contain a valid server payload.',
      );
    }

    AppLogger.info(
      'JellyfinApiClient: Public system info received: '
      '"${server.serverName}" (version ${server.serverVersion}).',
    );
    return server;
  }

  /// Authenticates with username and password and returns the raw session.
  ///
  /// The password travels only inside the request body and is never logged.
  Future<JellyfinAuthentication> authenticateByName({
    required String baseUrl,
    required String username,
    required String password,
    required String deviceId,
  }) async {
    AppLogger.info(
      _redactor.redact('JellyfinApiClient: Authenticating user on $baseUrl.'),
    );

    final response = await _send(
      _urlBuilder.authenticateByName(baseUrl),
      method: 'POST',
      baseUrl: baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'X-Emby-Authorization':
            'MediaBrowser Client="$_clientName", Device="$_clientName", '
            'DeviceId="$deviceId", Version="$_clientVersion", Token=""',
      },
      body: {'Username': username, 'Pw': password},
    );

    if (response.statusCode == 401) {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidCredentials,
        statusCode: 401,
        message: 'Username or password was rejected.',
      );
    }
    if (response.statusCode != 200) {
      throw JellyfinApiException(
        kind: JellyfinFailureKind.unknown,
        statusCode: response.statusCode,
        message: 'Authentication request failed.',
      );
    }

    final JellyfinAuthentication authentication;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      final user = decoded['User'];
      if (user is! Map<String, dynamic>) {
        throw const FormatException('Missing user payload.');
      }
      final accessToken = decoded['AccessToken'] as String?;
      final userId = user['Id'] as String?;
      final userName = user['Name'] as String?;
      final serverId = decoded['ServerId'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          userId == null ||
          userName == null ||
          serverId == null) {
        throw const FormatException('Missing authentication fields.');
      }
      authentication = JellyfinAuthentication(
        accessToken: accessToken,
        userId: userId,
        username: userName,
        serverId: serverId,
      );
    } on FormatException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.unknown,
        message: 'Authentication response could not be parsed.',
      );
    }

    AppLogger.info(
      _redactor.redact(
        'JellyfinApiClient: Authentication succeeded on $baseUrl.',
      ),
    );
    return authentication;
  }

  /// Ends the server session for [connection]. Best-effort: callers clear
  /// local credentials regardless of the outcome.
  Future<void> logout(JellyfinConnection connection) async {
    AppLogger.info(
      _redactor.redact(
        'JellyfinApiClient: Ending session on ${connection.baseUrl}.',
      ),
    );
    await _send(
      _urlBuilder.sessionsLogout(connection.baseUrl),
      method: 'POST',
      baseUrl: connection.baseUrl,
      headers: {'X-Emby-Token': connection.accessToken},
    );
  }

  /// User views (libraries) of the connected user.
  Future<List<JellyfinLibrary>> fetchUserViews(
    JellyfinConnection connection,
  ) async {
    final response = await _get(
      connection,
      _urlBuilder.userViewsWithFields(connection.baseUrl, connection.userId),
      operation: 'Views',
    );
    return _decodeItemPayload(response).map(JellyfinLibrary.fromJson).toList();
  }

  /// Continue-watching items of the connected user.
  Future<List<JellyfinItem>> fetchResumeItems(
    JellyfinConnection connection, {
    int limit = 24,
  }) async {
    final response = await _get(
      connection,
      _urlBuilder.resumeItemsWithFields(
        connection.baseUrl,
        connection.userId,
        limit: limit,
      ),
      operation: 'Resume',
    );
    return _decodeItemPayload(response).map(JellyfinItem.fromJson).toList();
  }

  /// Next-up episodes of the connected user.
  Future<List<JellyfinItem>> fetchNextUp(
    JellyfinConnection connection, {
    int limit = 12,
  }) async {
    final response = await _get(
      connection,
      _urlBuilder.nextUpWithFields(
        connection.baseUrl,
        connection.userId,
        limit: limit,
      ),
      operation: 'NextUp',
    );
    return _decodeItemPayload(response).map(JellyfinItem.fromJson).toList();
  }

  /// Latest additions across all libraries (bare JSON array response).
  Future<List<JellyfinItem>> fetchLatestItems(
    JellyfinConnection connection, {
    int limit = 16,
  }) async {
    final response = await _get(
      connection,
      _urlBuilder.latestItemsWithFields(
        connection.baseUrl,
        connection.userId,
        limit: limit,
      ),
      operation: 'Latest',
    );
    return _decodeArrayPayload(response).map(JellyfinItem.fromJson).toList();
  }

  /// Items inside a library, optionally filtered by item types.
  Future<List<JellyfinItem>> fetchLibraryItems(
    JellyfinConnection connection, {
    required String libraryId,
    List<String> itemTypes = const [],
  }) async {
    final response = await _get(
      connection,
      _urlBuilder.libraryItemsWithFields(
        connection.baseUrl,
        connection.userId,
        parentId: libraryId,
        itemTypes: itemTypes,
      ),
      operation: 'LibraryItems',
    );
    return _decodeItemPayload(response).map(JellyfinItem.fromJson).toList();
  }

  /// Full detail of a single item.
  Future<JellyfinItem> fetchItemDetail(
    JellyfinConnection connection, {
    required String itemId,
  }) async {
    final response = await _get(
      connection,
      _urlBuilder.itemDetailWithFields(
        connection.baseUrl,
        connection.userId,
        itemId,
      ),
      operation: 'ItemDetail',
    );
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      json = decoded;
    } on FormatException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.unknown,
        message: 'Item payload could not be parsed.',
      );
    }
    return JellyfinItem.fromJson(json);
  }

  /// Episodes of a series, grouped on the server by season order.
  Future<List<JellyfinItem>> fetchSeriesEpisodes(
    JellyfinConnection connection, {
    required String seriesId,
  }) async {
    final response = await _get(
      connection,
      _urlBuilder.seriesEpisodesWithFields(
        connection.baseUrl,
        connection.userId,
        seriesId,
      ),
      operation: 'SeriesEpisodes',
    );
    return _decodeItemPayload(response).map(JellyfinItem.fromJson).toList();
  }

  Future<http.Response> _get(
    JellyfinConnection connection,
    Uri uri, {
    required String operation,
  }) {
    AppLogger.info(
      _redactor.redact(
        'JellyfinApiClient: $operation on ${connection.baseUrl}.',
      ),
    );
    return _send(
      uri,
      method: 'GET',
      baseUrl: connection.baseUrl,
      headers: {'X-Emby-Token': connection.accessToken},
    );
  }

  List<Map<String, dynamic>> _decodeItemPayload(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected an object with an Items list.');
      }
      final items = decoded['Items'];
      if (items is! List) {
        throw const FormatException('Missing Items list.');
      }
      return items.whereType<Map<String, dynamic>>().toList();
    } on FormatException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.unknown,
        message: 'Items payload could not be parsed.',
      );
    }
  }

  List<Map<String, dynamic>> _decodeArrayPayload(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Expected a JSON array.');
      }
      return decoded.whereType<Map<String, dynamic>>().toList();
    } on FormatException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.unknown,
        message: 'Items payload could not be parsed.',
      );
    }
  }

  Future<http.Response> _send(
    Uri uri, {
    required String method,
    required String baseUrl,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, uri);
      if (headers != null) request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _transport.send(request).timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed);
      AppLogger.info(
        _redactor.redact(
          'JellyfinApiClient: $method ${uri.path} → ${response.statusCode}.',
        ),
      );
      return response;
    } on TimeoutException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.timeout,
        message: 'The request timed out.',
      );
    } on SocketException catch (error) {
      throw JellyfinApiException(
        kind: _classifySocketError(error),
        message: 'The server could not be reached.',
      );
    } on HandshakeException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.tls,
        message: 'The TLS handshake failed.',
      );
    } on TlsException {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.tls,
        message: 'The TLS handshake failed.',
      );
    } on http.ClientException catch (error) {
      throw JellyfinApiException(
        kind: _classifyClientError(error),
        message: 'The HTTP request failed.',
      );
    }
  }

  JellyfinFailureKind _classifySocketError(SocketException error) {
    final code = error.osError?.errorCode;
    if (code == 10061 || code == 111) {
      return JellyfinFailureKind.connectionRefused;
    }
    if (code == 11001 || code == 11002 || code == 8) {
      return JellyfinFailureKind.dns;
    }
    if (code == 10060 || code == 110) {
      return JellyfinFailureKind.timeout;
    }
    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('name or service not known') ||
        message.contains('getaddrinfo')) {
      return JellyfinFailureKind.dns;
    }
    if (message.contains('connection refused') ||
        message.contains('connection reset')) {
      return JellyfinFailureKind.connectionRefused;
    }
    if (message.contains('timed out')) {
      return JellyfinFailureKind.timeout;
    }
    return JellyfinFailureKind.hostUnreachable;
  }

  JellyfinFailureKind _classifyClientError(http.ClientException error) {
    final message = error.message.toLowerCase();
    if (message.contains('timed out')) {
      return JellyfinFailureKind.timeout;
    }
    if (message.contains('connection refused')) {
      return JellyfinFailureKind.connectionRefused;
    }
    if (message.contains('connection closed') ||
        message.contains('failed to connect') ||
        message.contains('failed host lookup')) {
      return JellyfinFailureKind.hostUnreachable;
    }
    return JellyfinFailureKind.unknown;
  }
}
