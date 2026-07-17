/// Persisted resume point for a series within a playlist.
class SeriesResumeState {
  const SeriesResumeState({
    required this.episodeId,
    required this.episodeTitle,
    required this.streamUrl,
    required this.positionMs,
    this.season,
    this.episodeNum,
  });

  final String episodeId;
  final String episodeTitle;
  final String streamUrl;
  final int positionMs;
  final int? season;
  final int? episodeNum;

  Map<String, dynamic> toJson() => {
    'episodeId': episodeId,
    'episodeTitle': episodeTitle,
    'streamUrl': streamUrl,
    'positionMs': positionMs,
    if (season != null) 'season': season,
    if (episodeNum != null) 'episodeNum': episodeNum,
  };

  factory SeriesResumeState.fromJson(Map<String, dynamic> json) {
    return SeriesResumeState(
      episodeId: json['episodeId'] as String,
      episodeTitle: json['episodeTitle'] as String,
      streamUrl: json['streamUrl'] as String,
      positionMs: json['positionMs'] as int? ?? 0,
      season: json['season'] as int?,
      episodeNum: json['episodeNum'] as int?,
    );
  }

  String get label {
    if (season != null && episodeNum != null) {
      return 'S${season!.toString().padLeft(2, '0')}'
          'E${episodeNum!.toString().padLeft(2, '0')} — $episodeTitle';
    }
    return episodeTitle;
  }
}
