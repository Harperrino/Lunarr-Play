import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_http_client.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_uri.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_data_source.dart';

class TmdbDiscoveryClient implements DiscoveryDataSource {
  TmdbDiscoveryClient({
    required DiscoveryHttpClient httpClient,
    required String readAccessToken,
    DateTime Function()? clock,
  }) : _http = httpClient,
       _token = readAccessToken.trim(),
       _clock = clock ?? DateTime.now;

  static final Uri _apiBase = Uri.https('api.themoviedb.org', '/3/');
  static final Uri _imageBase = Uri.https('image.tmdb.org', '/t/p/');

  final DiscoveryHttpClient _http;
  final String _token;
  final DateTime Function() _clock;

  Map<String, String> get _headers {
    if (_token.isEmpty) {
      throw const DiscoveryApiException(
        DiscoveryFailureKind.missingConfiguration,
      );
    }
    return <String, String>{'Authorization': 'Bearer $_token'};
  }

  Future<void> testConnection() async {
    await _getObject('configuration', const <String, String>{});
  }

  @override
  Future<DiscoveryHomeFeed> fetchHome(DiscoveryLocale locale) async {
    final now = _clock().toUtc();
    final common = <String, String>{
      'language': locale.languageTag,
      'page': '1',
    };

    final values = await Future.wait<Object>(<Future<Object>>[
      _page('trending/all/day', common, fallbackType: null),
      _page('movie/popular', <String, String>{
        ...common,
        'region': locale.region,
      }, fallbackType: DiscoveryMediaType.movie),
      _page('tv/popular', common, fallbackType: DiscoveryMediaType.tv),
      _page('movie/upcoming', <String, String>{
        ...common,
        'region': locale.region,
      }, fallbackType: DiscoveryMediaType.movie),
      _page('tv/on_the_air', common, fallbackType: DiscoveryMediaType.tv),
      _topRated(locale: locale, page: 1),
    ]);

    final trending = values[0] as DiscoveryPage;
    return DiscoveryHomeFeed(
      source: DiscoverySource.tmdb,
      heroItems: trending.items.take(8).toList(growable: false),
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
  }) {
    final common = <String, String>{
      'language': locale.languageTag,
      'page': '${page.clamp(1, 500)}',
    };
    return switch (kind) {
      DiscoveryShelfKind.popularMovies => _page(
        'movie/popular',
        <String, String>{...common, 'region': locale.region},
        fallbackType: DiscoveryMediaType.movie,
      ),
      DiscoveryShelfKind.popularTv => _page(
        'tv/popular',
        common,
        fallbackType: DiscoveryMediaType.tv,
      ),
      DiscoveryShelfKind.upcomingMovies => _page(
        'movie/upcoming',
        <String, String>{...common, 'region': locale.region},
        fallbackType: DiscoveryMediaType.movie,
      ),
      DiscoveryShelfKind.onTheAir => _page(
        'tv/on_the_air',
        common,
        fallbackType: DiscoveryMediaType.tv,
      ),
      DiscoveryShelfKind.topRated => _topRated(locale: locale, page: page),
    };
  }

  Future<DiscoveryPage> _topRated({
    required DiscoveryLocale locale,
    required int page,
  }) async {
    final common = <String, String>{
      'language': locale.languageTag,
      'page': '${page.clamp(1, 500)}',
    };
    final pages = await Future.wait<DiscoveryPage>(<Future<DiscoveryPage>>[
      _page('movie/top_rated', common, fallbackType: DiscoveryMediaType.movie),
      _page('tv/top_rated', common, fallbackType: DiscoveryMediaType.tv),
    ]);
    return _mergeRankedPages(pages);
  }

  @override
  Future<DiscoveryPage> search(
    String query, {
    required DiscoveryLocale locale,
    int page = 1,
  }) => _page('search/multi', <String, String>{
    'query': query.trim(),
    'page': '$page',
    'language': locale.languageTag,
    'include_adult': 'true',
  }, fallbackType: null);

  @override
  Future<DiscoveryMediaItem> fetchDetails(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
  }) async {
    final path = '${item.mediaType.name}/${item.id}';
    final values = await Future.wait<Object>(<Future<Object>>[
      _getObject(path, <String, String>{'language': locale.languageTag}),
      _loadTrailers(item, locale),
    ]);
    return _item(
      values[0] as Map<Object?, Object?>,
      fallbackType: item.mediaType,
    ).copyWith(trailers: values[1] as List<DiscoveryTrailer>);
  }

  Future<List<DiscoveryTrailer>> _loadTrailers(
    DiscoveryMediaItem item,
    DiscoveryLocale locale,
  ) async {
    try {
      final localized = await _videoPage(item, locale.languageTag);
      final hasTrailer = localized.any(
        (video) => video.type == DiscoveryTrailerType.trailer,
      );
      final combined = <DiscoveryTrailer>[...localized];
      if (!hasTrailer && locale.language.toLowerCase() != 'en') {
        combined.addAll(await _videoPage(item, 'en-US'));
      }
      return _rankTrailers(combined, locale.language);
    } catch (_) {
      return const <DiscoveryTrailer>[];
    }
  }

  Future<List<DiscoveryTrailer>> _videoPage(
    DiscoveryMediaItem item,
    String language,
  ) async {
    final json = await _getObject(
      '${item.mediaType.name}/${item.id}/videos',
      <String, String>{'language': language},
    );
    final raw = json['results'];
    if (raw is! List) return const <DiscoveryTrailer>[];
    return raw
        .whereType<Map>()
        .map(_tmdbTrailer)
        .whereType<DiscoveryTrailer>()
        .toList(growable: false);
  }

  Future<DiscoveryPage> _page(
    String path,
    Map<String, String> query, {
    required DiscoveryMediaType? fallbackType,
  }) async {
    final json = await _getObject(path, query);
    final rawResults = json['results'];
    final results = rawResults is List ? rawResults : const <Object?>[];
    final items = <DiscoveryMediaItem>[];
    for (final result in results) {
      if (result is! Map) continue;
      final mediaType = _mediaType(result, fallbackType: fallbackType);
      if (mediaType == null) continue; // Person and unknown result types.
      final item = _item(result, fallbackType: mediaType);
      if (item.id > 0 && item.title.isNotEmpty) items.add(item);
    }
    return DiscoveryPage(
      items: items,
      page: _int(json['page']) ?? 1,
      totalPages: (_int(json['total_pages']) ?? 1).clamp(1, 500),
    );
  }

  Future<Map<Object?, Object?>> _getObject(
    String path,
    Map<String, String> query,
  ) async {
    final uri = discoveryUriWithQuery(_apiBase.resolve(path), query);
    final response = await _http.get(uri, headers: _headers);
    _checkStatus(response.statusCode);
    if (response.json is! Map) {
      throw const DiscoveryApiException(DiscoveryFailureKind.invalidResponse);
    }
    return response.json! as Map<Object?, Object?>;
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
          ? json['original_title']
          : json['original_name'],
    );
    final rawGenres = json['genres'];
    final genres = rawGenres is List
        ? rawGenres
              .whereType<Map>()
              .map((entry) => _string(entry['name']))
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final rawSeasons = json['seasons'];
    final seasons = rawSeasons is List
        ? rawSeasons
              .whereType<Map>()
              .map(
                (entry) => DiscoverySeason(
                  number: _int(entry['season_number']) ?? 0,
                  name: _string(entry['name']),
                  episodeCount: _int(entry['episode_count']) ?? 0,
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
      posterUrl: _imageUrl(json['poster_path'], 'w500'),
      backdropUrl: _imageUrl(json['backdrop_path'], 'w1280'),
      releaseDate: DateTime.tryParse(
        _string(
          type == DiscoveryMediaType.movie
              ? json['release_date']
              : json['first_air_date'],
        ),
      ),
      voteAverage: _double(json['vote_average']),
      runtimeMinutes: _int(
        type == DiscoveryMediaType.movie
            ? json['runtime']
            : (json['episode_run_time'] is List &&
                  (json['episode_run_time'] as List).isNotEmpty)
            ? (json['episode_run_time'] as List).first
            : null,
      ),
      adult: json['adult'] == true,
      genres: genres,
      seasons: seasons,
    );
  }

  DiscoveryMediaType? _mediaType(
    Map<Object?, Object?> json, {
    required DiscoveryMediaType? fallbackType,
  }) => switch (json['media_type']?.toString()) {
    'movie' => DiscoveryMediaType.movie,
    'tv' => DiscoveryMediaType.tv,
    'person' => null,
    _ => fallbackType,
  };

  String? _imageUrl(Object? path, String size) {
    final value = _string(path);
    if (value.isEmpty) return null;
    return _imageBase
        .resolve('$size/${value.replaceFirst(RegExp(r'^/'), '')}')
        .toString();
  }

  void _checkStatus(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return;
    if (statusCode == 401) {
      throw const DiscoveryApiException(DiscoveryFailureKind.unauthorized);
    }
    if (statusCode == 403) {
      throw const DiscoveryApiException(DiscoveryFailureKind.forbidden);
    }
    throw DiscoveryApiException(
      DiscoveryFailureKind.invalidResponse,
      statusCode: statusCode,
    );
  }
}

DiscoveryTrailer? _tmdbTrailer(Map<Object?, Object?> json) {
  if (_string(json['site']).toLowerCase() != 'youtube') return null;
  final key = _string(json['key']).trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{6,64}$').hasMatch(key)) return null;
  final type = _trailerType(_string(json['type']));
  return DiscoveryTrailer(
    title: _string(json['name']).trim(),
    type: type,
    provider: DiscoveryTrailerProvider.youtube,
    official: json['official'] == true,
    key: key,
    watchUrl: Uri.https('www.youtube.com', '/watch', <String, String>{
      'v': key,
    }).toString(),
    language: _string(json['iso_639_1']).toLowerCase(),
  );
}

List<DiscoveryTrailer> _rankTrailers(
  Iterable<DiscoveryTrailer> input,
  String preferredLanguage,
) {
  final unique = <String, DiscoveryTrailer>{};
  for (final video in input) {
    unique.putIfAbsent('${video.provider.name}:${video.key}', () => video);
  }
  final result = unique.values.toList(growable: false)
    ..sort((left, right) {
      int rank(DiscoveryTrailer trailer) {
        final localized = trailer.language == preferredLanguage.toLowerCase();
        if (localized &&
            trailer.official &&
            trailer.type == DiscoveryTrailerType.trailer) {
          return 0;
        }
        if (localized && trailer.type == DiscoveryTrailerType.trailer) return 1;
        if (trailer.language == 'en' &&
            trailer.type == DiscoveryTrailerType.trailer) {
          return trailer.official ? 2 : 3;
        }
        return switch (trailer.type) {
          DiscoveryTrailerType.teaser => 4,
          DiscoveryTrailerType.trailer => 5,
          DiscoveryTrailerType.featurette => 6,
          DiscoveryTrailerType.clip => 7,
          DiscoveryTrailerType.other => 8,
        };
      }

      final priority = rank(left).compareTo(rank(right));
      return priority != 0 ? priority : left.title.compareTo(right.title);
    });
  return result;
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
