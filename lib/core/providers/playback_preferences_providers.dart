import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';

final playbackPreferencesProvider =
    AsyncNotifierProvider<PlaybackPreferencesNotifier, PlaybackPreferences>(
      PlaybackPreferencesNotifier.new,
    );

class PlaybackPreferencesNotifier extends AsyncNotifier<PlaybackPreferences> {
  Future<void> _ambientWriteQueue = Future<void>.value();
  int _ambientGeneration = 0;

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

  Future<void> setAmbientBackgroundEnabled(bool value) async {
    await _updateAmbient(
      (current) => current.copyWith(ambientBackgroundEnabled: value),
      () => ref
          .read(appStateRepositoryProvider)
          .setPlayerAmbientBackgroundEnabled(value),
    );
  }

  Future<void> setAmbientPreset(PlayerAmbientPreset value) async {
    await _updateAmbient(
      (current) => current.copyWith(ambientPreset: value),
      () => ref.read(appStateRepositoryProvider).setPlayerAmbientPreset(value),
    );
  }

  Future<void> setAmbientCustomHueA(double value) async {
    final normalized = normalizeAmbientHue(value);
    await _updateAmbient(
      (current) => current.copyWith(ambientCustomHueA: normalized),
      () => ref
          .read(appStateRepositoryProvider)
          .setPlayerAmbientCustomHueA(normalized),
    );
  }

  void previewAmbientCustomHueA(double value) {
    _ambientGeneration++;
    final normalized = normalizeAmbientHue(value);
    state = AsyncData(_current.copyWith(ambientCustomHueA: normalized));
  }

  Future<void> setAmbientCustomHueB(double value) async {
    final normalized = normalizeAmbientHue(value);
    await _updateAmbient(
      (current) => current.copyWith(ambientCustomHueB: normalized),
      () => ref
          .read(appStateRepositoryProvider)
          .setPlayerAmbientCustomHueB(normalized),
    );
  }

  void previewAmbientCustomHueB(double value) {
    _ambientGeneration++;
    final normalized = normalizeAmbientHue(value);
    state = AsyncData(_current.copyWith(ambientCustomHueB: normalized));
  }

  Future<void> setAmbientIntensity(double value) async {
    final normalized = normalizeAmbientIntensity(value);
    await _updateAmbient(
      (current) => current.copyWith(ambientIntensity: normalized),
      () => ref
          .read(appStateRepositoryProvider)
          .setPlayerAmbientIntensity(normalized),
    );
  }

  void previewAmbientIntensity(double value) {
    _ambientGeneration++;
    final normalized = normalizeAmbientIntensity(value);
    state = AsyncData(_current.copyWith(ambientIntensity: normalized));
  }

  Future<void> setAmbientMotion(PlayerAmbientMotion value) async {
    await _updateAmbient(
      (current) => current.copyWith(ambientMotion: value),
      () => ref.read(appStateRepositoryProvider).setPlayerAmbientMotion(value),
    );
  }

  Future<void> resetAmbientBackground() async {
    const defaults = PlaybackPreferences();
    await _updateAmbient(
      (current) => current.copyWith(
        ambientBackgroundEnabled: defaults.ambientBackgroundEnabled,
        ambientPreset: defaults.ambientPreset,
        ambientCustomHueA: defaults.ambientCustomHueA,
        ambientCustomHueB: defaults.ambientCustomHueB,
        ambientIntensity: defaults.ambientIntensity,
        ambientMotion: defaults.ambientMotion,
      ),
      () async {
        final repository = ref.read(appStateRepositoryProvider);
        await repository.setPlayerAmbientBackgroundEnabled(
          defaults.ambientBackgroundEnabled,
        );
        await repository.setPlayerAmbientPreset(defaults.ambientPreset);
        await repository.setPlayerAmbientCustomHueA(defaults.ambientCustomHueA);
        await repository.setPlayerAmbientCustomHueB(defaults.ambientCustomHueB);
        await repository.setPlayerAmbientIntensity(defaults.ambientIntensity);
        await repository.setPlayerAmbientMotion(defaults.ambientMotion);
      },
    );
  }

  Future<void> _updateAmbient(
    PlaybackPreferences Function(PlaybackPreferences current) update,
    Future<void> Function() persist,
  ) async {
    final generation = ++_ambientGeneration;
    state = AsyncData(update(_current));
    final operation = _ambientWriteQueue.then((_) => persist());
    _ambientWriteQueue = operation.then<void>((_) {}, onError: (_, _) {});
    try {
      await operation;
    } catch (_) {
      if (generation != _ambientGeneration) return;
      try {
        final persisted = await ref
            .read(appStateRepositoryProvider)
            .getPlaybackPreferences();
        if (generation == _ambientGeneration) state = AsyncData(persisted);
      } catch (_) {
        // The repository already records I/O failures. Keep the optimistic
        // value when neither the write nor a recovery read is available.
      }
    }
  }
}
