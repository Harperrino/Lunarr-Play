enum MediaSegmentSkipMode {
  off,
  button,
  automatic;

  static MediaSegmentSkipMode fromStorage(String? value) {
    return values.where((mode) => mode.name == value).firstOrNull ?? button;
  }
}

const playbackSeekIntervalOptions = <int>[5, 10, 15, 30, 60];
const playbackEndcardCountdownOptions = <int>[5, 10, 15, 20, 30];

int normalizePlaybackSeekInterval(int value) =>
    playbackSeekIntervalOptions.contains(value) ? value : 15;

int normalizeEndcardCountdown(int value) =>
    playbackEndcardCountdownOptions.contains(value) ? value : 10;

class PlaybackPreferences {
  const PlaybackPreferences({
    this.seekIntervalSeconds = 15,
    this.trickplayEnabled = true,
    this.mediaSegmentSkipMode = MediaSegmentSkipMode.button,
    this.nextEpisodeAutoplayEnabled = true,
    this.endcardCountdownSeconds = 10,
  });

  final int seekIntervalSeconds;
  final bool trickplayEnabled;
  final MediaSegmentSkipMode mediaSegmentSkipMode;
  final bool nextEpisodeAutoplayEnabled;
  final int endcardCountdownSeconds;

  PlaybackPreferences copyWith({
    int? seekIntervalSeconds,
    bool? trickplayEnabled,
    MediaSegmentSkipMode? mediaSegmentSkipMode,
    bool? nextEpisodeAutoplayEnabled,
    int? endcardCountdownSeconds,
  }) => PlaybackPreferences(
    seekIntervalSeconds: seekIntervalSeconds ?? this.seekIntervalSeconds,
    trickplayEnabled: trickplayEnabled ?? this.trickplayEnabled,
    mediaSegmentSkipMode: mediaSegmentSkipMode ?? this.mediaSegmentSkipMode,
    nextEpisodeAutoplayEnabled:
        nextEpisodeAutoplayEnabled ?? this.nextEpisodeAutoplayEnabled,
    endcardCountdownSeconds:
        endcardCountdownSeconds ?? this.endcardCountdownSeconds,
  );
}
