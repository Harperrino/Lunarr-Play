/// Subset of the Jellyfin item DTO that Lunarr actually renders.
///
/// The parser only reads the fields below and ignores unknown JSON members so
/// that future server extensions cannot break parsing.
class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.type,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
    this.productionYear,
    this.overview = '',
    this.runTimeTicks = 0,
    this.playbackPositionTicks = 0,
    this.played = false,
    this.primaryImageTag,
    this.backdropImageTag,
  });

  final String id;
  final String name;
  final String type;
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? productionYear;
  final String overview;
  final int runTimeTicks;
  final int playbackPositionTicks;
  final bool played;
  final String? primaryImageTag;
  final String? backdropImageTag;

  bool get isMovie => type == 'Movie';
  bool get isSeries => type == 'Series';
  bool get isEpisode => type == 'Episode';
  bool get hasResume =>
      !played && playbackPositionTicks > 0 && runTimeTicks > 0;

  double get resumeFraction {
    if (!hasResume || runTimeTicks <= 0) return 0;
    return (playbackPositionTicks / runTimeTicks).clamp(0.0, 1.0);
  }

  factory JellyfinItem.fromJson(Map<String, dynamic> json) {
    final imageTags = json['ImageTags'];
    final imageTagsMap = imageTags is Map<String, dynamic> ? imageTags : null;
    final userData = json['UserData'];
    final userDataMap = userData is Map<String, dynamic> ? userData : null;

    return JellyfinItem(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      type: json['Type'] as String? ?? '',
      seriesName: json['SeriesName'] as String?,
      seasonNumber: json['ParentIndexNumber'] as int?,
      episodeNumber: json['IndexNumber'] as int?,
      productionYear: json['ProductionYear'] as int?,
      overview: json['Overview'] as String? ?? '',
      runTimeTicks: json['RunTimeTicks'] as int? ?? 0,
      playbackPositionTicks:
          userDataMap?['PlaybackPositionTicks'] as int? ?? 0,
      played: userDataMap?['Played'] as bool? ?? false,
      primaryImageTag:
          imageTagsMap?['Primary'] as String? ??
          json['PrimaryImageTag'] as String?,
      backdropImageTag:
          imageTagsMap?['Backdrop'] as String? ??
          json['BackdropImageTag'] as String?,
    );
  }
}
