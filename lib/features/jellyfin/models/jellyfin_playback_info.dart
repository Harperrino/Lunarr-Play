/// Media-source subset of a Jellyfin `PlaybackInfoResponse`.
class JellyfinMediaSource {
  const JellyfinMediaSource({
    required this.id,
    this.container = '',
    this.supportsDirectPlay = false,
    this.supportsDirectStream = false,
    this.supportsTranscoding = false,
  });

  final String id;
  final String container;
  final bool supportsDirectPlay;
  final bool supportsDirectStream;
  final bool supportsTranscoding;

  factory JellyfinMediaSource.fromJson(Map<String, dynamic> json) {
    return JellyfinMediaSource(
      id: json['Id'] as String? ?? '',
      container: json['Container'] as String? ?? '',
      supportsDirectPlay: json['SupportsDirectPlay'] as bool? ?? false,
      supportsDirectStream: json['SupportsDirectStream'] as bool? ?? false,
      supportsTranscoding: json['SupportsTranscoding'] as bool? ?? false,
    );
  }
}

/// Parsed `PlaybackInfoResponse`; unknown fields are ignored.
class JellyfinPlaybackInfo {
  const JellyfinPlaybackInfo({
    this.mediaSources = const [],
    this.playSessionId,
  });

  final List<JellyfinMediaSource> mediaSources;
  final String? playSessionId;

  factory JellyfinPlaybackInfo.fromJson(Map<String, dynamic> json) {
    final sources = json['MediaSources'];
    return JellyfinPlaybackInfo(
      mediaSources: sources is List
          ? sources
                .whereType<Map<String, dynamic>>()
                .map(JellyfinMediaSource.fromJson)
                .toList()
          : const [],
      playSessionId: json['PlaySessionId'] as String?,
    );
  }
}
