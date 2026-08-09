/// Detail-oriented subset of Jellyfin's BaseItemDto.
///
/// The parser intentionally ignores unknown JSON members so server additions
/// cannot break the feature. Image ownership is kept separately because
/// episodes commonly inherit their backdrop from the parent series.
class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.seriesId,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
    this.productionYear,
    this.overview = '',
    this.runTimeTicks = 0,
    this.playbackPositionTicks = 0,
    this.played = false,
    this.favorite = false,
    this.primaryImageTag,
    this.logoImageTag,
    this.backdropImageTag,
    this.backdropItemId,
    this.officialRating,
    this.communityRating,
    this.criticRating,
    this.providerIds = const {},
    this.genres = const [],
    this.taglines = const [],
    this.studios = const [],
    this.people = const [],
    this.remoteTrailers = const [],
  });

  final String id;
  final String name;
  final String type;
  final String? seriesId;
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? productionYear;
  final String overview;
  final int runTimeTicks;
  final int playbackPositionTicks;
  final bool played;
  final bool favorite;
  final String? primaryImageTag;
  final String? logoImageTag;
  final String? backdropImageTag;

  /// Item owning [backdropImageTag]; episodes commonly inherit series art.
  final String? backdropItemId;

  final String? officialRating;
  final double? communityRating;
  final double? criticRating;
  final Map<String, String> providerIds;
  final List<String> genres;
  final List<String> taglines;
  final List<String> studios;
  final List<JellyfinPerson> people;
  final List<JellyfinTrailer> remoteTrailers;

  bool get isMovie => type == 'Movie';
  bool get isSeries => type == 'Series';
  bool get isEpisode => type == 'Episode';
  bool get isFavorite => favorite;
  bool get hasResume =>
      !played && playbackPositionTicks > 0 && runTimeTicks > 0;

  double get resumeFraction {
    if (!hasResume || runTimeTicks <= 0) return 0;
    return (playbackPositionTicks / runTimeTicks).clamp(0.0, 1.0);
  }

  factory JellyfinItem.fromJson(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    final imageTagsMap = imageTags is Map
        ? Map<String, dynamic>.from(imageTags)
        : null;
    final userData = json['UserData'];
    final userDataMap = userData is Map
        ? Map<String, dynamic>.from(userData)
        : null;

    final parentBackdropTags = json['ParentBackdropImageTags'];
    final parentBackdropTag = _firstString(parentBackdropTags);
    final ownBackdropTag =
        _firstString(json['BackdropImageTags']) ??
        imageTagsMap?['Backdrop'] as String? ??
        json['BackdropImageTag'] as String?;
    final backdropImageTag = ownBackdropTag ?? parentBackdropTag;
    final parentBackdropItemId =
        json['ParentBackdropItemId'] as String? ?? json['SeriesId'] as String?;

    return JellyfinItem(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      type: json['Type'] as String? ?? '',
      seriesId: json['SeriesId'] as String?,
      seriesName: json['SeriesName'] as String?,
      seasonNumber: json['ParentIndexNumber'] as int?,
      episodeNumber: json['IndexNumber'] as int?,
      productionYear: json['ProductionYear'] as int?,
      overview: json['Overview'] as String? ?? '',
      runTimeTicks: _intValue(json['RunTimeTicks']),
      playbackPositionTicks: _intValue(userDataMap?['PlaybackPositionTicks']),
      played: userDataMap?['Played'] as bool? ?? false,
      favorite: userDataMap?['IsFavorite'] as bool? ?? false,
      primaryImageTag:
          imageTagsMap?['Primary'] as String? ??
          json['PrimaryImageTag'] as String?,
      logoImageTag:
          imageTagsMap?['Logo'] as String? ?? json['LogoImageTag'] as String?,
      backdropImageTag: backdropImageTag,
      backdropItemId: ownBackdropTag == null && parentBackdropTag != null
          ? parentBackdropItemId
          : null,
      officialRating: json['OfficialRating'] as String?,
      communityRating: _doubleValue(json['CommunityRating']),
      criticRating: _doubleValue(json['CriticRating']),
      providerIds: _stringMap(json['ProviderIds']),
      genres: _stringList(json['Genres']),
      taglines: _stringList(json['Taglines']),
      studios: _namedList(json['Studios']),
      people: _peopleList(json['People']),
      remoteTrailers: _trailersList(json['RemoteTrailers']),
    );
  }
}

class JellyfinPerson {
  const JellyfinPerson({required this.name, this.role, this.type});

  final String name;
  final String? role;
  final String? type;

  factory JellyfinPerson.fromJson(Map<String, dynamic> json) {
    return JellyfinPerson(
      name: json['Name'] as String? ?? '',
      role: json['Role'] as String?,
      type: json['Type'] as String?,
    );
  }
}

class JellyfinTrailer {
  const JellyfinTrailer({required this.url, this.name});

  final String url;
  final String? name;

  factory JellyfinTrailer.fromJson(Map<String, dynamic> json) {
    return JellyfinTrailer(
      url: json['Url'] as String? ?? '',
      name: json['Name'] as String?,
    );
  }
}

String? _firstString(Object? value) {
  if (value is! List) return null;
  for (final entry in value) {
    if (entry is String && entry.isNotEmpty) return entry;
  }
  return null;
}

int _intValue(Object? value) => value is num ? value.toInt() : 0;

double? _doubleValue(Object? value) => value is num ? value.toDouble() : null;

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return Map<String, String>.fromEntries(
    value.entries
        .where((entry) => entry.key is String && entry.value is String)
        .map((entry) => MapEntry(entry.key as String, entry.value as String)),
  );
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().where((value) => value.isNotEmpty).toList();
}

List<String> _namedList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((entry) {
        if (entry is String) return entry;
        if (entry is Map) return entry['Name'] as String? ?? '';
        return '';
      })
      .where((value) => value.isNotEmpty)
      .toList();
}

List<JellyfinPerson> _peopleList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => JellyfinPerson.fromJson(Map<String, dynamic>.from(entry)))
      .where((person) => person.name.isNotEmpty)
      .toList();
}

List<JellyfinTrailer> _trailersList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (entry) => JellyfinTrailer.fromJson(Map<String, dynamic>.from(entry)),
      )
      .where((trailer) => trailer.url.isNotEmpty)
      .toList();
}
