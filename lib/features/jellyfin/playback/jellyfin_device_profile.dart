/// Static device profile describing the container/codec support that the
/// bundled media_kit/libmpv build provides. Sent with every PlaybackInfo
/// request so the server can pick a Direct Play source.
class JellyfinDeviceProfile {
  const JellyfinDeviceProfile({
    this.maxStaticBitrate = 120000000,
    this.supportedContainers = const ['mp4', 'mkv', 'm4v', 'mov', 'webm', 'ts'],
    this.supportedVideoCodecs = const [
      'h264',
      'hevc',
      'vp9',
      'av1',
      'mpeg4',
      'vc1',
    ],
    this.supportedAudioCodecs = const [
      'aac',
      'ac3',
      'eac3',
      'mp3',
      'flac',
      'opus',
      'vorbis',
      'pcm_s16le',
      'pcm_s24le',
    ],
  });

  final int maxStaticBitrate;
  final List<String> supportedContainers;
  final List<String> supportedVideoCodecs;
  final List<String> supportedAudioCodecs;

  Map<String, dynamic> toJson() {
    return {
      'MaxStaticBitrate': maxStaticBitrate,
      'DirectPlayProfiles': [
        {
          'Container': supportedContainers.join(','),
          'VideoCodec': supportedVideoCodecs.join(','),
          'AudioCodec': supportedAudioCodecs.join(','),
        },
      ],
    };
  }
}
