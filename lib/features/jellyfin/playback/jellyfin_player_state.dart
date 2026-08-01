import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_resolver.dart';

/// Immutable UI state of the Jellyfin player instance.
class JellyfinPlayerState {
  const JellyfinPlayerState({
    this.initialized = false,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.volume = 1.0,
    this.muted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error = false,
    this.title = '',
    this.method,
  });

  /// True once a media source has been opened on the player.
  final bool initialized;
  final bool playing;
  final bool buffering;
  final bool completed;
  final double volume;
  final bool muted;
  final Duration position;
  final Duration duration;

  /// Set when opening or playback fails; the UI localizes the message.
  final bool error;
  final String title;
  final JellyfinPlaybackMethod? method;

  JellyfinPlayerState copyWith({
    bool? initialized,
    bool? playing,
    bool? buffering,
    bool? completed,
    double? volume,
    bool? muted,
    Duration? position,
    Duration? duration,
    bool? error,
    String? title,
    JellyfinPlaybackMethod? method,
  }) {
    return JellyfinPlayerState(
      initialized: initialized ?? this.initialized,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      completed: completed ?? this.completed,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error ?? this.error,
      title: title ?? this.title,
      method: method ?? this.method,
    );
  }
}
