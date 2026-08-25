import 'package:m3uxtream_player/core/models/discovery_preferences.dart';

enum DiscoveryMediaType { movie, tv }

enum DiscoveryAvailability {
  unknown,
  pending,
  processing,
  partiallyAvailable,
  available,
  deleted,
}

enum DiscoveryRequestStatus { none, pending, approved, declined }

enum DiscoveryTrailerType { trailer, teaser, clip, featurette, other }

enum DiscoveryTrailerProvider { youtube, external }

enum DiscoveryShelfKind {
  popularMovies,
  popularTv,
  upcomingMovies,
  onTheAir,
  topRated,
}

class DiscoverySeason {
  const DiscoverySeason({
    required this.number,
    required this.name,
    required this.episodeCount,
  });

  final int number;
  final String name;
  final int episodeCount;

  factory DiscoverySeason.fromJson(Object? value) {
    final json = value is Map ? value : const <Object?, Object?>{};
    return DiscoverySeason(
      number: _asInt(json['number'] ?? json['season_number']) ?? 0,
      name: _asString(json['name']),
      episodeCount: _asInt(json['episodeCount'] ?? json['episode_count']) ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    'name': name,
    'episodeCount': episodeCount,
  };
}

class DiscoveryTrailer {
  const DiscoveryTrailer({
    required this.title,
    required this.type,
    required this.provider,
    required this.official,
    required this.key,
    required this.watchUrl,
    this.language = '',
  });

  final String title;
  final DiscoveryTrailerType type;
  final DiscoveryTrailerProvider provider;
  final bool official;
  final String key;
  final String watchUrl;
  final String language;

  Uri? get validatedWatchUri {
    final uri = Uri.tryParse(watchUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  factory DiscoveryTrailer.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid trailer.');
    return DiscoveryTrailer(
      title: _asString(value['title']),
      type: DiscoveryTrailerType.values.firstWhere(
        (entry) => entry.name == value['type'],
        orElse: () => DiscoveryTrailerType.other,
      ),
      provider: DiscoveryTrailerProvider.values.firstWhere(
        (entry) => entry.name == value['provider'],
        orElse: () => DiscoveryTrailerProvider.external,
      ),
      official: value['official'] == true,
      key: _asString(value['key']),
      watchUrl: _asString(value['watchUrl']),
      language: _asString(value['language']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'type': type.name,
    'provider': provider.name,
    'official': official,
    'key': key,
    'watchUrl': watchUrl,
    'language': language,
  };
}

class DiscoveryMediaItem {
  const DiscoveryMediaItem({
    required this.id,
    required this.mediaType,
    required this.title,
    this.originalTitle = '',
    this.overview = '',
    this.posterUrl,
    this.backdropUrl,
    this.releaseDate,
    this.voteAverage,
    this.runtimeMinutes,
    this.adult = false,
    this.genres = const <String>[],
    this.seasons = const <DiscoverySeason>[],
    this.trailers = const <DiscoveryTrailer>[],
    this.availability = DiscoveryAvailability.unknown,
    this.requestStatus = DiscoveryRequestStatus.none,
  });

  final int id;
  final DiscoveryMediaType mediaType;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterUrl;
  final String? backdropUrl;
  final DateTime? releaseDate;
  final double? voteAverage;
  final int? runtimeMinutes;
  final bool adult;
  final List<String> genres;
  final List<DiscoverySeason> seasons;
  final List<DiscoveryTrailer> trailers;
  final DiscoveryAvailability availability;
  final DiscoveryRequestStatus requestStatus;

  bool get canRequest =>
      availability != DiscoveryAvailability.available &&
      availability != DiscoveryAvailability.partiallyAvailable &&
      requestStatus == DiscoveryRequestStatus.none;

  DiscoveryMediaItem copyWith({
    String? title,
    String? originalTitle,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    DateTime? releaseDate,
    double? voteAverage,
    int? runtimeMinutes,
    bool? adult,
    List<String>? genres,
    List<DiscoverySeason>? seasons,
    List<DiscoveryTrailer>? trailers,
    DiscoveryAvailability? availability,
    DiscoveryRequestStatus? requestStatus,
  }) => DiscoveryMediaItem(
    id: id,
    mediaType: mediaType,
    title: title ?? this.title,
    originalTitle: originalTitle ?? this.originalTitle,
    overview: overview ?? this.overview,
    posterUrl: posterUrl ?? this.posterUrl,
    backdropUrl: backdropUrl ?? this.backdropUrl,
    releaseDate: releaseDate ?? this.releaseDate,
    voteAverage: voteAverage ?? this.voteAverage,
    runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
    adult: adult ?? this.adult,
    genres: genres ?? this.genres,
    seasons: seasons ?? this.seasons,
    trailers: trailers ?? this.trailers,
    availability: availability ?? this.availability,
    requestStatus: requestStatus ?? this.requestStatus,
  );

  factory DiscoveryMediaItem.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid media item.');
    final mediaType = switch (value['mediaType']) {
      'tv' => DiscoveryMediaType.tv,
      _ => DiscoveryMediaType.movie,
    };
    return DiscoveryMediaItem(
      id: _asInt(value['id']) ?? 0,
      mediaType: mediaType,
      title: _asString(value['title']),
      originalTitle: _asString(value['originalTitle']),
      overview: _asString(value['overview']),
      posterUrl: _nullableString(value['posterUrl']),
      backdropUrl: _nullableString(value['backdropUrl']),
      releaseDate: DateTime.tryParse(_asString(value['releaseDate'])),
      voteAverage: _asDouble(value['voteAverage']),
      runtimeMinutes: _asInt(value['runtimeMinutes']),
      adult: value['adult'] == true,
      genres: _stringList(value['genres']),
      seasons: _list(value['seasons'])
          .map(DiscoverySeason.fromJson)
          .toList(growable: false),
      trailers: _list(value['trailers'])
          .map(DiscoveryTrailer.fromJson)
          .where((trailer) => trailer.validatedWatchUri != null)
          .toList(growable: false),
      availability: DiscoveryAvailability.values.firstWhere(
        (item) => item.name == value['availability'],
        orElse: () => DiscoveryAvailability.unknown,
      ),
      requestStatus: DiscoveryRequestStatus.values.firstWhere(
        (item) => item.name == value['requestStatus'],
        orElse: () => DiscoveryRequestStatus.none,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'mediaType': mediaType.name,
    'title': title,
    'originalTitle': originalTitle,
    'overview': overview,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'releaseDate': releaseDate?.toIso8601String(),
    'voteAverage': voteAverage,
    'runtimeMinutes': runtimeMinutes,
    'adult': adult,
    'genres': genres,
    'seasons': seasons.map((item) => item.toJson()).toList(growable: false),
    'trailers': trailers.map((item) => item.toJson()).toList(growable: false),
    'availability': availability.name,
    'requestStatus': requestStatus.name,
  };
}

class DiscoveryPage {
  const DiscoveryPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<DiscoveryMediaItem> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

class DiscoveryShelf {
  const DiscoveryShelf({
    required this.kind,
    required this.items,
    this.page = 1,
    this.totalPages = 1,
  });

  final DiscoveryShelfKind kind;
  final List<DiscoveryMediaItem> items;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;

  factory DiscoveryShelf.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid discovery shelf.');
    final kind = DiscoveryShelfKind.values.firstWhere(
      (item) => item.name == value['kind'],
      orElse: () => throw const FormatException('Unknown discovery shelf.'),
    );
    return DiscoveryShelf(
      kind: kind,
      items: _list(value['items'])
          .map(DiscoveryMediaItem.fromJson)
          .toList(growable: false),
      page: (_asInt(value['page']) ?? 1).clamp(1, 500),
      totalPages: (_asInt(value['totalPages']) ?? 1).clamp(1, 500),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'page': page,
    'totalPages': totalPages,
  };
}

class DiscoveryHomeFeed {
  const DiscoveryHomeFeed({
    required this.source,
    required this.heroItems,
    required this.shelves,
    required this.fetchedAt,
    this.isStale = false,
  });

  final DiscoverySource source;
  final List<DiscoveryMediaItem> heroItems;
  final List<DiscoveryShelf> shelves;
  final DateTime fetchedAt;
  final bool isStale;

  DiscoveryHomeFeed copyWith({bool? isStale}) => DiscoveryHomeFeed(
    source: source,
    heroItems: heroItems,
    shelves: shelves,
    fetchedAt: fetchedAt,
    isStale: isStale ?? this.isStale,
  );

  factory DiscoveryHomeFeed.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid discovery feed.');
    return DiscoveryHomeFeed(
      source: DiscoverySource.fromStorage(_nullableString(value['source'])),
      heroItems: _list(value['heroItems'])
          .map(DiscoveryMediaItem.fromJson)
          .toList(growable: false),
      shelves: _list(value['shelves'])
          .map(DiscoveryShelf.fromJson)
          .toList(growable: false),
      fetchedAt:
          DateTime.tryParse(_asString(value['fetchedAt'])) ?? DateTime(1970),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.name,
    'heroItems': heroItems.map((item) => item.toJson()).toList(growable: false),
    'shelves': shelves.map((item) => item.toJson()).toList(growable: false),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };
}

class DiscoveryLocale {
  const DiscoveryLocale({required this.language, required this.region});

  final String language;
  final String region;

  String get languageTag => '${language.toLowerCase()}-${region.toUpperCase()}';
  String get cacheKey => '${language.toLowerCase()}_${region.toUpperCase()}';
}

int? _asInt(Object? value) => value is num
    ? value.toInt()
    : value is String
    ? int.tryParse(value)
    : null;

double? _asDouble(Object? value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;

String _asString(Object? value) => value?.toString() ?? '';
String? _nullableString(Object? value) {
  final text = _asString(value).trim();
  return text.isEmpty ? null : text;
}

List<Object?> _list(Object? value) => value is List ? value : const [];
List<String> _stringList(Object? value) =>
    _list(value).map(_asString).where((item) => item.isNotEmpty).toList();
