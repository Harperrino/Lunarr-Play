/// The stream kinds used by Jellyfin's `MediaStreams` payload.
enum JellyfinMediaStreamType { audio, video, subtitle, unknown }

/// A feature-local representation of one Jellyfin media stream.
class JellyfinMediaStream {
  const JellyfinMediaStream({
    required this.index,
    this.type = JellyfinMediaStreamType.unknown,
    this.codec = '',
    this.language = '',
    this.displayTitle = '',
    this.title = '',
    this.isDefault = false,
    this.isForced = false,
    this.channels,
    this.channelLayout = '',
    this.profile = '',
    this.isExternal = false,
    this.supportsExternalStream = false,
    this.isTextSubtitleStream = false,
  });

  final int index;
  final JellyfinMediaStreamType type;
  final String codec;
  final String language;
  final String displayTitle;
  final String title;
  final bool isDefault;
  final bool isForced;
  final int? channels;
  final String channelLayout;
  final String profile;
  final bool isExternal;
  final bool supportsExternalStream;
  final bool isTextSubtitleStream;

  factory JellyfinMediaStream.fromJson(Map<String, dynamic> json) {
    return JellyfinMediaStream(
      index: _asInt(json['Index']) ?? -1,
      type: _streamType(json['Type']),
      codec: json['Codec'] as String? ?? '',
      language: json['Language'] as String? ?? '',
      displayTitle: json['DisplayTitle'] as String? ?? '',
      title: json['Title'] as String? ?? '',
      isDefault: json['IsDefault'] as bool? ?? false,
      isForced: json['IsForced'] as bool? ?? false,
      channels: _asInt(json['Channels']),
      channelLayout: json['ChannelLayout'] as String? ?? '',
      profile: json['Profile'] as String? ?? '',
      isExternal: json['IsExternal'] as bool? ?? false,
      supportsExternalStream: json['SupportsExternalStream'] as bool? ?? false,
      isTextSubtitleStream: json['IsTextSubtitleStream'] as bool? ?? false,
    );
  }
}

/// Media-source subset of a Jellyfin `PlaybackInfoResponse`.
class JellyfinMediaSource {
  const JellyfinMediaSource({
    required this.id,
    this.container = '',
    this.protocol = '',
    this.supportsDirectPlay = false,
    this.supportsDirectStream = false,
    this.supportsTranscoding = false,
    this.transcodingUrl,
    this.transcodingContainer,
    this.transcodingSubProtocol,
    this.mediaStreams = const [],
    this.defaultAudioStreamIndex,
    this.defaultSubtitleStreamIndex,
  });

  final String id;
  final String container;
  final String protocol;
  final bool supportsDirectPlay;
  final bool supportsDirectStream;
  final bool supportsTranscoding;
  final String? transcodingUrl;
  final String? transcodingContainer;
  final String? transcodingSubProtocol;
  final List<JellyfinMediaStream> mediaStreams;
  final int? defaultAudioStreamIndex;
  final int? defaultSubtitleStreamIndex;

  factory JellyfinMediaSource.fromJson(Map<String, dynamic> json) {
    return JellyfinMediaSource(
      id: json['Id'] as String? ?? '',
      container: json['Container'] as String? ?? '',
      protocol: json['Protocol']?.toString() ?? '',
      supportsDirectPlay: json['SupportsDirectPlay'] as bool? ?? false,
      supportsDirectStream: json['SupportsDirectStream'] as bool? ?? false,
      supportsTranscoding: json['SupportsTranscoding'] as bool? ?? false,
      transcodingUrl: json['TranscodingUrl'] as String?,
      transcodingContainer: json['TranscodingContainer'] as String?,
      transcodingSubProtocol: json['TranscodingSubProtocol']?.toString(),
      mediaStreams: _parseMediaStreams(json['MediaStreams']),
      defaultAudioStreamIndex: _asInt(json['DefaultAudioStreamIndex']),
      defaultSubtitleStreamIndex: _asInt(json['DefaultSubtitleStreamIndex']),
    );
  }
}

/// Parsed `PlaybackInfoResponse`; unknown fields are ignored.
class JellyfinPlaybackInfo {
  const JellyfinPlaybackInfo({
    this.mediaSources = const [],
    this.mediaStreams = const [],
    this.playSessionId,
    this.defaultAudioStreamIndex,
    this.defaultSubtitleStreamIndex,
  });

  final List<JellyfinMediaSource> mediaSources;
  final List<JellyfinMediaStream> mediaStreams;
  final String? playSessionId;
  final int? defaultAudioStreamIndex;
  final int? defaultSubtitleStreamIndex;

  factory JellyfinPlaybackInfo.fromJson(Map<String, dynamic> json) {
    final sources = json['MediaSources'];
    final mediaSources = sources is List
        ? sources
              .whereType<Map<String, dynamic>>()
              .map(JellyfinMediaSource.fromJson)
              .toList()
        : const <JellyfinMediaSource>[];
    final responseStreams = _parseMediaStreams(json['MediaStreams']);
    final firstSource = mediaSources.isNotEmpty ? mediaSources.first : null;
    return JellyfinPlaybackInfo(
      mediaSources: mediaSources,
      mediaStreams: responseStreams.isNotEmpty
          ? responseStreams
          : firstSource?.mediaStreams ?? const [],
      playSessionId: json['PlaySessionId'] as String?,
      defaultAudioStreamIndex:
          firstSource?.defaultAudioStreamIndex ??
          _asInt(json['DefaultAudioStreamIndex']),
      defaultSubtitleStreamIndex:
          firstSource?.defaultSubtitleStreamIndex ??
          _asInt(json['DefaultSubtitleStreamIndex']),
    );
  }
}

List<JellyfinMediaStream> _parseMediaStreams(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(JellyfinMediaStream.fromJson)
      .toList();
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

JellyfinMediaStreamType _streamType(Object? value) {
  if (value is int) {
    return switch (value) {
      0 => JellyfinMediaStreamType.audio,
      1 => JellyfinMediaStreamType.video,
      2 => JellyfinMediaStreamType.subtitle,
      _ => JellyfinMediaStreamType.unknown,
    };
  }
  return switch (value?.toString().toLowerCase()) {
    'audio' => JellyfinMediaStreamType.audio,
    'video' => JellyfinMediaStreamType.video,
    'subtitle' || 'subtitles' => JellyfinMediaStreamType.subtitle,
    _ => JellyfinMediaStreamType.unknown,
  };
}
