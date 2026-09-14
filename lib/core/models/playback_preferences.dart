enum MediaSegmentSkipMode {
  off,
  button,
  automatic;

  static MediaSegmentSkipMode fromStorage(String? value) {
    return values.where((mode) => mode.name == value).firstOrNull ?? button;
  }
}

enum PlayerAmbientPreset {
  lunarr,
  aurora,
  ember,
  custom;

  static PlayerAmbientPreset fromStorage(String? value) =>
      values.firstWhere((entry) => entry.name == value, orElse: () => lunarr);
}

enum PlayerAmbientMotion {
  slow,
  normal,
  fast;

  static PlayerAmbientMotion fromStorage(String? value) =>
      values.firstWhere((entry) => entry.name == value, orElse: () => slow);
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
    this.ambientBackgroundEnabled = true,
    this.ambientPreset = PlayerAmbientPreset.lunarr,
    this.ambientCustomHueA = 215,
    this.ambientCustomHueB = 285,
    this.ambientIntensity = 0.55,
    this.ambientMotion = PlayerAmbientMotion.slow,
  });

  final int seekIntervalSeconds;
  final bool trickplayEnabled;
  final MediaSegmentSkipMode mediaSegmentSkipMode;
  final bool nextEpisodeAutoplayEnabled;
  final int endcardCountdownSeconds;
  final bool ambientBackgroundEnabled;
  final PlayerAmbientPreset ambientPreset;
  final double ambientCustomHueA;
  final double ambientCustomHueB;
  final double ambientIntensity;
  final PlayerAmbientMotion ambientMotion;

  PlaybackPreferences copyWith({
    int? seekIntervalSeconds,
    bool? trickplayEnabled,
    MediaSegmentSkipMode? mediaSegmentSkipMode,
    bool? nextEpisodeAutoplayEnabled,
    int? endcardCountdownSeconds,
    bool? ambientBackgroundEnabled,
    PlayerAmbientPreset? ambientPreset,
    double? ambientCustomHueA,
    double? ambientCustomHueB,
    double? ambientIntensity,
    PlayerAmbientMotion? ambientMotion,
  }) => PlaybackPreferences(
    seekIntervalSeconds: seekIntervalSeconds ?? this.seekIntervalSeconds,
    trickplayEnabled: trickplayEnabled ?? this.trickplayEnabled,
    mediaSegmentSkipMode: mediaSegmentSkipMode ?? this.mediaSegmentSkipMode,
    nextEpisodeAutoplayEnabled:
        nextEpisodeAutoplayEnabled ?? this.nextEpisodeAutoplayEnabled,
    endcardCountdownSeconds:
        endcardCountdownSeconds ?? this.endcardCountdownSeconds,
    ambientBackgroundEnabled:
        ambientBackgroundEnabled ?? this.ambientBackgroundEnabled,
    ambientPreset: ambientPreset ?? this.ambientPreset,
    ambientCustomHueA: normalizeAmbientHue(
      ambientCustomHueA ?? this.ambientCustomHueA,
    ),
    ambientCustomHueB: normalizeAmbientHue(
      ambientCustomHueB ?? this.ambientCustomHueB,
    ),
    ambientIntensity: normalizeAmbientIntensity(
      ambientIntensity ?? this.ambientIntensity,
    ),
    ambientMotion: ambientMotion ?? this.ambientMotion,
  );
}

double normalizeAmbientHue(double value) =>
    value.isFinite ? value.clamp(0, 360).toDouble() : 215;

double normalizeAmbientIntensity(double value) =>
    value.isFinite ? value.clamp(0, 1).toDouble() : 0.55;
