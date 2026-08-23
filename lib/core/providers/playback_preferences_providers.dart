import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';

final playbackPreferencesProvider =
    AsyncNotifierProvider<PlaybackPreferencesNotifier, PlaybackPreferences>(
      PlaybackPreferencesNotifier.new,
    );

class PlaybackPreferencesNotifier extends AsyncNotifier<PlaybackPreferences> {
  @override
  Future<PlaybackPreferences> build() =>
      ref.read(appStateRepositoryProvider).getPlaybackPreferences();

  PlaybackPreferences get _current =>
      state.valueOrNull ?? const PlaybackPreferences();

  Future<void> setSeekIntervalSeconds(int value) async {
    final normalized = normalizePlaybackSeekInterval(value);
    await ref
        .read(appStateRepositoryProvider)
        .setPlaybackSeekIntervalSeconds(normalized);
    state = AsyncData(_current.copyWith(seekIntervalSeconds: normalized));
  }

  Future<void> setTrickplayEnabled(bool value) async {
    await ref
        .read(appStateRepositoryProvider)
        .setJellyfinTrickplayEnabled(value);
    state = AsyncData(_current.copyWith(trickplayEnabled: value));
  }

  Future<void> setMediaSegmentSkipMode(MediaSegmentSkipMode value) async {
    await ref
        .read(appStateRepositoryProvider)
        .setJellyfinMediaSegmentSkipMode(value);
    state = AsyncData(_current.copyWith(mediaSegmentSkipMode: value));
  }

  Future<void> setNextEpisodeAutoplayEnabled(bool value) async {
    await ref
        .read(appStateRepositoryProvider)
        .setJellyfinNextEpisodeAutoplayEnabled(value);
    state = AsyncData(_current.copyWith(nextEpisodeAutoplayEnabled: value));
  }

  Future<void> setEndcardCountdownSeconds(int value) async {
    final normalized = normalizeEndcardCountdown(value);
    await ref
        .read(appStateRepositoryProvider)
        .setJellyfinEndcardCountdownSeconds(normalized);
    state = AsyncData(_current.copyWith(endcardCountdownSeconds: normalized));
  }
}
