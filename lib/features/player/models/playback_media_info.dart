/// Snapshot of decoded stream parameters from media_kit (mpv).
class PlaybackMediaInfo {
  const PlaybackMediaInfo({
    this.playbackUri,
    this.videoWidth,
    this.videoHeight,
    this.videoPixelFormat,
    this.audioFormat,
    this.audioSampleRate,
    this.audioChannelCount,
    this.audioChannelsLabel,
    this.audioBitrateKbps,
  });

  final String? playbackUri;
  final int? videoWidth;
  final int? videoHeight;
  final String? videoPixelFormat;
  final String? audioFormat;
  final int? audioSampleRate;
  final int? audioChannelCount;
  final String? audioChannelsLabel;
  final double? audioBitrateKbps;

  bool get hasAny =>
      playbackUri != null ||
      videoWidth != null ||
      videoHeight != null ||
      videoPixelFormat != null ||
      audioFormat != null ||
      audioSampleRate != null ||
      audioChannelCount != null ||
      audioBitrateKbps != null;

  bool get hasAudioInfo =>
      audioFormat != null ||
      audioSampleRate != null ||
      audioChannelCount != null ||
      audioChannelsLabel != null;

  String? get resolutionLabel {
    if (videoWidth == null || videoHeight == null) return null;
    if (videoWidth! <= 0 || videoHeight! <= 0) return null;
    return '$videoWidth×$videoHeight';
  }

  String? get containerLabel {
    final uri = playbackUri;
    if (uri == null || uri.isEmpty) return null;
    final path = Uri.tryParse(uri)?.path ?? uri;
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return null;
    return path.substring(dot + 1).toUpperCase();
  }

  static const empty = PlaybackMediaInfo();

  PlaybackMediaInfo copyWith({
    String? playbackUri,
    int? videoWidth,
    int? videoHeight,
    String? videoPixelFormat,
    String? audioFormat,
    int? audioSampleRate,
    int? audioChannelCount,
    String? audioChannelsLabel,
    double? audioBitrateKbps,
    bool clearAll = false,
  }) {
    if (clearAll) return PlaybackMediaInfo.empty;
    return PlaybackMediaInfo(
      playbackUri: playbackUri ?? this.playbackUri,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      videoPixelFormat: videoPixelFormat ?? this.videoPixelFormat,
      audioFormat: audioFormat ?? this.audioFormat,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannelCount: audioChannelCount ?? this.audioChannelCount,
      audioChannelsLabel: audioChannelsLabel ?? this.audioChannelsLabel,
      audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
    );
  }
}

/// End of the forward-buffered range on the VOD timeline (ms).
int vodBufferedEndMs({
  required int positionMs,
  required int forwardBufferMs,
  required int durationMs,
}) {
  if (durationMs <= 0) return 0;
  return (positionMs + forwardBufferMs).clamp(0, durationMs);
}
