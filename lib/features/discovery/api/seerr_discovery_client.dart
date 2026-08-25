import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_http_client.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_data_source.dart';

class SeerrConnectionResult {
  const SeerrConnectionResult({required this.version});

  final String version;
}

class SeerrDiscoveryClient implements RequestCapableDiscoveryDataSource {
  SeerrDiscoveryClient({
    required DiscoveryHttpClient httpClient,
    required String endpoint,
    required String apiKey,
    DateTime Function()? clock,
  }) : _http = httpClient,
       _baseUri = normalizeSeerrApiBase(endpoint),
       _apiKey = apiKey.trim(),
       _clock = clock ?? DateTime.now;

  final DiscoveryHttpClient _http;
  final Uri _baseUri;
  final String _apiKey;
  final DateTime Function() _clock;
  Future<void>? _compatibilityCheck;
  String? _compatibleVersion;

  Uri get baseUri => _baseUri;
  bool get usesInsecureHttp => _baseUri.scheme == 'http';

  Map<String, String> get _headers {
    if (_apiKey.isEmpty) {
      throw const DiscoveryApiException(
        DiscoveryFailureKind.missingConfiguration,
      );
    }
    return <String, String>{'X-Api-Key': _apiKey};
  }

  Future<SeerrConnectionResult> testConnection() async {
    await _ensureCompatible();
    // A public status response alone does not validate the supplied key.
    await _getObject('discover/trending', const <String, String>{
      'page': '1',
      'mediaType': 'all',
    });
    return SeerrConnectionResult(version: _compatibleVersion!);
  }

  Future<void> _ensureCompatible() =>
      _compatibilityCheck ??= _checkCompatibility();

  Future<void> _checkCompatibility() async {
    final status = await _getObject('status', const <String, String>{
      'checkUpdateAvailable': 'false',
    }, authenticated: false);
    final version = _string(status['version']);
    if (!seerrVersionAtLeast(version, 3, 1, 0)) {
      throw const DiscoveryApiException(
        DiscoveryFailureKind.unsupportedVersion,
      );
    }
    _compatibleVersion = version;
  }

  @override
  Future<DiscoveryHomeFeed> fetchHome(DiscoveryLocale locale) async {
    await _ensureCompatible();
    final now = _clock().toUtc();
    final today = _date(now);
    final nextWeek = _date(now.add(const Duration(days: 7)));
    final common = <String, String>{'page': '1', 'language': locale.language};
    final values = await Future.wait<Object>(<Future<Object>>[
      _page('discover/trending', <String, String>{
        ...common,
        'mediaType': 'all',
        'timeWindow': 'day',
      }, fallbackType: null),
      _page('discover/movies', <String, String>{
        ...common,
        'sortBy': 'popularity.desc',
      }, fallbackType: DiscoveryMediaType.movie),
      _page('discover/tv', <String, String>{
        ...common,
        'sortBy': 'popularity.desc',
      }, fallbackType: DiscoveryMediaType.tv),
      _page(
        'discover/movies/upcoming',
        common,
        fallbackType: DiscoveryMediaType.movie,
      ),
      _page('discover/tv', <String, String>{
        ...common,
        'firstAirDateGte': today,
        'firstAirDateLte': nextWeek,
        'sortBy': 'popularity.desc',
      }, fallbackType: DiscoveryMediaType.tv),
      _topRated(locale: locale, page: 1),
    ]);
    return DiscoveryHomeFeed(
      source: DiscoverySource.seerr,
      heroItems: (values[0] as DiscoveryPage).items
          .take(8)
          .toList(growable: false),
      shelves: <DiscoveryShelf>[
        _shelf(DiscoveryShelfKind.popularMovies, values[1] as DiscoveryPage),
        _shelf(DiscoveryShelfKind.popularTv, values[2] as DiscoveryPage),
        _shelf(DiscoveryShelfKind.upcomingMovies, values[3] as DiscoveryPage),
        _shelf(DiscoveryShelfKind.onTheAir, values[4] as DiscoveryPage),
        _shelf(DiscoveryShelfKind.topRated, values[5] as DiscoveryPage),
      ],
      fetchedAt: now,
    );
  }

  @override
  Future<DiscoveryPage> fetchCategory(
    DiscoveryShelfKind kind, {
    required DiscoveryLocale locale,
    int page = 1,
  }) async {
    await _ensureCompatible();
    final now = _clock().toUtc();
    final common = <String, String>{
      'page': '${page.clamp(1, 500)}',
      'language': locale.language,
    };
    return switch (kind) {
      DiscoveryShelfKind.popularMovies => _page(
        'discover/movies',
        <String, String>{...common, 'sortBy': 'popularity.desc'},
        fallbackType: DiscoveryMediaType.movie,
      ),
      DiscoveryShelfKind.popularTv => _page('discover/tv', <String, String>{
        ...common,
        'sortBy': 'popularity.desc',
      }, fallbackType: DiscoveryMediaType.tv),
      DiscoveryShelfKind.upcomingMovies => _page(
        'discover/movies/upcoming',
        common,
        fallbackType: DiscoveryMediaType.movie,
      ),
      DiscoveryShelfKind.onTheAir => _page('discover/tv', <String, String>{
        ...common,
        'firstAirDateGte': _date(now),
        'firstAirDateLte': _date(now.add(const Duration(days: 7))),
        'sortBy': 'popularity.desc',
      }, fallbackType: DiscoveryMediaType.tv),
      DiscoveryShelfKind.topRated => _topRated(locale: locale, page: page),
    };
  }

  Future<DiscoveryPage> _topRated({
    required DiscoveryLocale locale,
    required int page,
  }) async {
    final common = <String, String>{
      'page': '${page.clamp(1, 500)}',
      'language': locale.language,
    };
    final pages = await Future.wait<DiscoveryPage>(<Future<DiscoveryPage>>[
      _page('discover/movies', <String, String>{
        ...common,
        'sortBy': 'vote_average.desc',
        'voteCountGte': '100',
      }, fallbackType: DiscoveryMediaType.movie),
      _page('discover/tv', <String, String>{
        ...common,
        'sortBy': 'vote_average.desc',
        'voteCountGte': '100',
      }, fallbackType: DiscoveryMediaType.tv),
    ]);
    return _mergeRankedPages(pages);
  }

  @override
  Future<DiscoveryPage> search(
    String query, {
    required DiscoveryLocale locale,
    int page = 1,
  }) async {
    await _ensureCompatible();
    return _page('search', <String, String>{
      'query': query.trim(),
      'page': '$page',
      'language': locale.language,
    }, fallbackType: null);
  }

  @override
  Future<DiscoveryMediaItem> fetchDetails(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
  }) async {
    await _ensureCompatible();
    final json = await _getObject(
      '${item.mediaType.name}/${item.id}',
      <String, String>{'language': locale.language},
    );
    return _item(json, fallbackType: item.mediaType).copyWith(
      trailers: _seerrTrailers(json['relatedVideos'] ?? json['related_videos']),
    );
  }

  @override
  Future<DiscoveryMediaItem> requestMedia(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
    List<int>? seasons,
  }) async {
    await _ensureCompatible();
    final response = await _http.post(
      _uri('request'),
      headers: _headers,
      body: <String, Object?>{
        'mediaType': item.mediaType.name,
        'mediaId': item.id,
        if (item.mediaType == DiscoveryMediaType.tv)
          'seasons': seasons == null || seasons.isEmpty ? 'all' : seasons,
        'is4k': false,
      },
    );
    _checkStatus(response.statusCode);
    return fetchDetails(item, locale: locale);
  }

  Future<DiscoveryPage> _page(
    String path,
    Map<String, String> query, {
    required DiscoveryMediaType? fallbackType,
  }) async {
    final json = await _getObject(path, query);
    final raw = json['results'];
    final results = raw is List ? raw : const <Object?>[];
    final items = <DiscoveryMediaItem>[];
    for (final result in results) {
      if (result is! Map) continue;
      final type = _mediaType(result, fallbackType: fallbackType);
      if (type == null) continue;
      final item = _item(result, fallbackType: type);
      if (item.id > 0 && item.title.isNotEmpty) items.add(item);
    }
    return DiscoveryPage(
      items: items,
      page: _int(json['page']) ?? 1,
      totalPages: (_int(json['totalPages']) ?? 1).clamp(1, 500),
    );
  }

  Future<Map<Object?, Object?>> _getObject(
    String path,
    Map<String, String> query, {
    bool authenticated = true,
  }) async {
    final response = await _http.get(
      _uri(path, query),
      headers: authenticated ? _headers : const <String, String>{},
    );
    _checkStatus(response.statusCode);
    if (response.json is! Map) {
      throw const DiscoveryApiException(DiscoveryFailureKind.invalidResponse);
    }
    return response.json! as Map<Object?, Object?>;
  }

  Uri _uri(String relativePath, [Map<String, String>? query]) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path
        : '${_baseUri.path}/';
    return _baseUri
        .replace(
          path: '$basePath${relativePath.replaceFirst(RegExp(r'^/'), '')}',
        )
        .replace(queryParameters: query);
  }

  DiscoveryMediaItem _item(
    Map<Object?, Object?> json, {
    required DiscoveryMediaType fallbackType,
  }) {
    final type = _mediaType(json, fallbackType: fallbackType) ?? fallbackType;
    final title = _string(
      type == DiscoveryMediaType.movie ? json['title'] : json['name'],
    );
    final originalTitle = _string(
      type == DiscoveryMediaType.movie
          ? json['originalTitle'] ?? json['original_title']
          : json['originalName'] ?? json['original_name'],
    );
    final mediaInfo = json['mediaInfo'] is Map
        ? json['mediaInfo'] as Map
        : json['media_info'] is Map
        ? json['media_info'] as Map
        : const <Object?, Object?>{};
    final requests = mediaInfo['requests'] is List
        ? mediaInfo['requests'] as List
        : const <Object?>[];
    final requestStatus = requests
        .whereType<Map>()
        .map((request) => _requestStatus(_int(request['status'])))
        .fold<DiscoveryRequestStatus>(
          DiscoveryRequestStatus.none,
          (current, next) =>
              current == DiscoveryRequestStatus.none ? next : current,
        );
    final rawGenres = json['genres'];
    final genres = rawGenres is List
        ? rawGenres
              .map(
                (entry) =>
                    entry is Map ? _string(entry['name']) : _string(entry),
              )
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final rawSeasons = json['seasons'];
    final seasons = rawSeasons is List
        ? rawSeasons
              .whereType<Map>()
              .map(
                (entry) => DiscoverySeason(
                  number:
                      _int(entry['seasonNumber'] ?? entry['season_number']) ??
                      0,
                  name: _string(entry['name']),
                  episodeCount:
                      _int(entry['episodeCount'] ?? entry['episode_count']) ??
                      0,
                ),
              )
              .toList(growable: false)
        : const <DiscoverySeason>[];
    return DiscoveryMediaItem(
      id: _int(json['id']) ?? 0,
      mediaType: type,
      title: title,
      originalTitle: originalTitle,
      overview: _string(json['overview']),
      posterUrl: _imageUrl(json['posterPath'] ?? json['poster_path'], 'w500'),
      backdropUrl: _imageUrl(
        json['backdropPath'] ?? json['backdrop_path'],
        'w1280',
      ),
      releaseDate: DateTime.tryParse(
        _string(
          type == DiscoveryMediaType.movie
              ? json['releaseDate'] ?? json['release_date']
              : json['firstAirDate'] ?? json['first_air_date'],
        ),
      ),
      voteAverage: _double(json['voteAverage'] ?? json['vote_average']),
      runtimeMinutes: _int(
        type == DiscoveryMediaType.movie
            ? json['runtime']
            : json['episodeRunTime'] is List &&
                  (json['episodeRunTime'] as List).isNotEmpty
            ? (json['episodeRunTime'] as List).first
            : null,
      ),
      adult: json['adult'] == true,
      genres: genres,
      seasons: seasons,
      availability: _availability(_int(mediaInfo['status'])),
      requestStatus: requestStatus,
    );
  }

  DiscoveryMediaType? _mediaType(
    Map<Object?, Object?> json, {
    required DiscoveryMediaType? fallbackType,
  }) => switch (json['mediaType'] ?? json['media_type']) {
    'movie' => DiscoveryMediaType.movie,
    'tv' => DiscoveryMediaType.tv,
    'person' => null,
    _ => fallbackType,
  };

  String? _imageUrl(Object? path, String size) {
    final value = _string(path);
    if (value.isEmpty) return null;
    return Uri.https(
      'image.tmdb.org',
      '/t/p/$size/${value.replaceFirst(RegExp(r'^/'), '')}',
    ).toString();
  }

  void _checkStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return;
    if (statusCode == 401) {
      throw const DiscoveryApiException(DiscoveryFailureKind.unauthorized);
    }
    if (statusCode == 403) {
      throw const DiscoveryApiException(DiscoveryFailureKind.forbidden);
    }
    if (statusCode == 409) {
      throw const DiscoveryApiException(DiscoveryFailureKind.conflict);
    }
    throw DiscoveryApiException(
      DiscoveryFailureKind.network,
      statusCode: statusCode,
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

List<DiscoveryTrailer> _seerrTrailers(Object? raw) {
  if (raw is! List) return const <DiscoveryTrailer>[];
  final seen = <String>{};
  final trailers = <DiscoveryTrailer>[];
  for (final entry in raw.whereType<Map>()) {
    final rawUrl = _string(entry['url']).trim();
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
      continue;
    }
    final isYoutube =
        _string(entry['site']).toLowerCase() == 'youtube' ||
        parsed.host == 'youtube.com' ||
        parsed.host == 'www.youtube.com' ||
        parsed.host == 'youtu.be';
    final key = _youtubeKey(entry['key'], parsed, isYoutube);
    if (isYoutube && key == null) continue;
    final identity = '${isYoutube ? 'youtube' : parsed.host}:${key ?? rawUrl}';
    if (!seen.add(identity)) continue;
    trailers.add(
      DiscoveryTrailer(
        title: _string(entry['name']).trim(),
        type: _trailerType(_string(entry['type'])),
        provider: isYoutube
            ? DiscoveryTrailerProvider.youtube
            : DiscoveryTrailerProvider.external,
        official: entry['official'] == true,
        key: key ?? rawUrl,
        watchUrl: isYoutube
            ? Uri.https('www.youtube.com', '/watch', <String, String>{
                'v': key!,
              }).toString()
            : parsed.toString(),
        language: _string(entry['iso_639_1']).toLowerCase(),
      ),
    );
  }
  trailers.sort((left, right) {
    int rank(DiscoveryTrailer item) => switch (item.type) {
      DiscoveryTrailerType.trailer => item.official ? 0 : 1,
      DiscoveryTrailerType.teaser => 2,
      DiscoveryTrailerType.featurette => 3,
      DiscoveryTrailerType.clip => 4,
      DiscoveryTrailerType.other => 5,
    };

    final priority = rank(left).compareTo(rank(right));
    return priority != 0 ? priority : left.title.compareTo(right.title);
  });
  return trailers;
}

String? _youtubeKey(Object? rawKey, Uri uri, bool isYoutube) {
  if (!isYoutube) return null;
  var key = _string(rawKey).trim();
  if (key.isEmpty) {
    key = uri.host == 'youtu.be'
        ? uri.pathSegments.firstOrNull ?? ''
        : uri.queryParameters['v'] ?? '';
  }
  return RegExp(r'^[A-Za-z0-9_-]{6,64}$').hasMatch(key) ? key : null;
}

DiscoveryTrailerType _trailerType(String value) =>
    switch (value.toLowerCase()) {
      'trailer' => DiscoveryTrailerType.trailer,
      'teaser' => DiscoveryTrailerType.teaser,
      'clip' => DiscoveryTrailerType.clip,
      'featurette' => DiscoveryTrailerType.featurette,
      _ => DiscoveryTrailerType.other,
    };

DiscoveryShelf _shelf(DiscoveryShelfKind kind, DiscoveryPage page) =>
    DiscoveryShelf(
      kind: kind,
      items: page.items,
      page: page.page,
      totalPages: page.totalPages,
    );

DiscoveryPage _mergeRankedPages(List<DiscoveryPage> pages) {
  final byIdentity = <String, DiscoveryMediaItem>{};
  for (final item in pages.expand((page) => page.items)) {
    byIdentity.putIfAbsent('${item.mediaType.name}:${item.id}', () => item);
  }
  final merged = byIdentity.values.toList(growable: false)
    ..sort((left, right) {
      final rating = (right.voteAverage ?? 0).compareTo(left.voteAverage ?? 0);
      if (rating != 0) return rating;
      final type = left.mediaType.index.compareTo(right.mediaType.index);
      return type != 0 ? type : left.id.compareTo(right.id);
    });
  return DiscoveryPage(
    items: merged,
    page: pages.map((entry) => entry.page).fold(1, (a, b) => a > b ? a : b),
    totalPages: pages
        .map((entry) => entry.totalPages)
        .fold(1, (a, b) => a > b ? a : b),
  );
}

Uri normalizeSeerrApiBase(String endpoint) {
  var raw = endpoint.trim();
  if (raw.isEmpty || raw.contains(RegExp(r'\s'))) {
    throw const DiscoveryApiException(DiscoveryFailureKind.invalidEndpoint);
  }
  if (!raw.contains('://')) raw = 'http://$raw';
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const DiscoveryApiException(DiscoveryFailureKind.invalidEndpoint);
  }
  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (!path.endsWith('/api/v1')) path = '$path/api/v1';
  return uri.replace(path: path, query: null, fragment: null);
}

bool seerrVersionAtLeast(String value, int major, int minor, int patch) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(value.trim());
  if (match == null) return false;
  final actual = <int>[
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
  final required = <int>[major, minor, patch];
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] > required[index]) return true;
    if (actual[index] < required[index]) return false;
  }
  return true;
}

DiscoveryAvailability _availability(int? status) => switch (status) {
  2 => DiscoveryAvailability.pending,
  3 => DiscoveryAvailability.processing,
  4 => DiscoveryAvailability.partiallyAvailable,
  5 => DiscoveryAvailability.available,
  6 => DiscoveryAvailability.deleted,
  _ => DiscoveryAvailability.unknown,
};

DiscoveryRequestStatus _requestStatus(int? status) => switch (status) {
  1 => DiscoveryRequestStatus.pending,
  2 => DiscoveryRequestStatus.approved,
  3 => DiscoveryRequestStatus.declined,
  _ => DiscoveryRequestStatus.none,
};

int? _int(Object? value) => value is num
    ? value.toInt()
    : value is String
    ? int.tryParse(value)
    : null;
double? _double(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;
String _string(Object? value) => value?.toString() ?? '';
