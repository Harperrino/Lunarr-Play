/// Static device profile describing the container/codec support that the
/// bundled media_kit/libmpv build provides. Sent with every PlaybackInfo
/// request so the server can pick a Direct Play source.
class JellyfinDeviceProfile {
  const JellyfinDeviceProfile({
    this.maxStreamingBitrate = 120000000,
    this.maxStaticBitrate = 120000000,
    this.supportedContainers = const ['mp4', 'mkv', 'm4v', 'mov', 'webm', 'ts'],
    this.supportedVideoCodecs = const [
      'h264',
      'hevc',
      'vp9',
      'av1',
      'mpeg4',
      'vc1',
      'mpeg2video',
    ],
    this.supportedAudioCodecs = const [
      'aac',
      'ac3',
      'eac3',
      'mp3',
      'flac',
      'dts',
      'opus',
      'vorbis',
      'pcm_s16le',
      'pcm_s24le',
    ],
    this.supportedSubtitleFormats = const [
      'srt',
      'ass',
      'ssa',
      'vtt',
      'pgssub',
      'vobsub',
    ],
  });

  final int maxStreamingBitrate;
  final int maxStaticBitrate;
  final List<String> supportedContainers;
  final List<String> supportedVideoCodecs;
  final List<String> supportedAudioCodecs;
  final List<String> supportedSubtitleFormats;

  Map<String, dynamic> toJson() {
    return {
      'MaxStreamingBitrate': maxStreamingBitrate,
      'MaxStaticBitrate': maxStaticBitrate,
      'DirectPlayProfiles': [
        {
          'Container': supportedContainers.join(','),
          'VideoCodec': supportedVideoCodecs.join(','),
          'AudioCodec': supportedAudioCodecs.join(','),
          'Type': 'Video',
        },
      ],
      'DirectStreamProfiles': [
        {
          'Container': supportedContainers.join(','),
          'VideoCodec': supportedVideoCodecs.join(','),
          'AudioCodec': supportedAudioCodecs.join(','),
          'Protocol': 'http',
          'Type': 'Video',
        },
      ],
      'TranscodingProfiles': [
        {
          'Container': 'ts',
          'VideoCodec': 'h264',
          'AudioCodec': 'aac',
          'Protocol': 'hls',
          'Context': 'Streaming',
          'Type': 'Video',
          'EnableSubtitlesInManifest': false,
        },
      ],
      'SubtitleProfiles': [
        for (final format in supportedSubtitleFormats)
          {'Format': format, 'Method': 'Embed'},
      ],
    };
  }
}
