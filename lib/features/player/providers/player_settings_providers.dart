import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';

const preferredAudioLanguageAutoValue = 'auto';

String? normalizePreferredAudioLanguage(String? language) {
  final normalized = language?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.toLowerCase() == preferredAudioLanguageAutoValue) return null;
  return normalized;
}

/// User-selectable live startup buffer targets in seconds.
///
/// 120 s is offered as the maximum practical value for very stable streams.
/// It needs up to ~256 MB of cache memory and increases channel-zap latency,
/// so it is labelled accordingly in the UI.
const liveStartupBufferSecondsOptions = <int>[0, 5, 10, 20, 30, 45, 60, 120];

/// Maps any stored value to the closest allowed option.
///
/// Existing presets are migrated automatically because the old code persisted
/// seconds, not enum names:
///   - Off (0) -> Off
///   - Low (5) -> 5 s
///   - Medium (15) -> 10 s (closest new value, keeps startup fast)
///   - High (60) -> 60 s
int normalizeLiveStartupBufferSeconds(int seconds) {
  if (seconds <= 0) return 0;
  var best = liveStartupBufferSecondsOptions.first;
  var bestDiff = (best - seconds).abs();
  for (var i = 1; i < liveStartupBufferSecondsOptions.length; i++) {
    final option = liveStartupBufferSecondsOptions[i];
    final diff = (option - seconds).abs();
    if (diff < bestDiff) {
      best = option;
      bestDiff = diff;
    }
  }
  return best;
}

String labelForLiveStartupBufferSeconds(int seconds) {
  final normalized = normalizeLiveStartupBufferSeconds(seconds);
  if (normalized == 0) return 'Aus';
  if (normalized == 120) return '120 Sekunden (maximal)';
  return '$normalized Sekunden';
}

Duration liveStartupBufferTimeoutForSeconds(int seconds) {
  if (seconds <= 0) return Duration.zero;
  final timeoutSeconds = (seconds + 10).clamp(12, 150).toInt();
  return Duration(seconds: timeoutSeconds);
}

/// User-configured live startup buffer target in seconds.
final playerBufferSecondsProvider =
    AsyncNotifierProvider<PlayerBufferSecondsNotifier, int>(
      PlayerBufferSecondsNotifier.new,
    );

class PlayerBufferSecondsNotifier extends AsyncNotifier<int> {
  /// Default is 10 s: the previous product default was 15 s ("Medium"), which
  /// is no longer a selectable concrete option. We intentionally map new/fresh
  /// state to the nearest lower preset so startup stays conservative on zap
  /// latency while legacy stored 15 s values normalize compatibly to 10 s.
  static const defaultSeconds = 10;

  @override
  Future<int> build() async {
    final stored = await ref
        .read(appStateRepositoryProvider)
        .getPlayerBufferSeconds(defaultSeconds: defaultSeconds);
    return normalizeLiveStartupBufferSeconds(stored);
  }

  Future<void> setSeconds(int seconds) async {
    final normalized = normalizeLiveStartupBufferSeconds(seconds);
    await ref
        .read(appStateRepositoryProvider)
        .setPlayerBufferSeconds(normalized);
    state = AsyncData(normalized);
  }
}

/// Forces stereo output for audio compatibility with external interfaces.
final forceStereoEnabledProvider =
    AsyncNotifierProvider<ForceStereoEnabledNotifier, bool>(
      ForceStereoEnabledNotifier.new,
    );

class ForceStereoEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(appStateRepositoryProvider).getForceStereoEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(appStateRepositoryProvider).setForceStereoEnabled(enabled);
    state = AsyncData(enabled);
  }
}

/// User-configured preferred audio language for automatic track selection.
/// `null` means "no preference / automatic".
final preferredAudioLanguageProvider =
    AsyncNotifierProvider<PreferredAudioLanguageNotifier, String?>(
      PreferredAudioLanguageNotifier.new,
    );

class PreferredAudioLanguageNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    return ref.read(appStateRepositoryProvider).getPreferredAudioLanguage();
  }

  Future<void> setLanguage(String? language) async {
    final normalized = normalizePreferredAudioLanguage(language);
    await ref
        .read(appStateRepositoryProvider)
        .setPreferredAudioLanguage(normalized);
    state = AsyncData(normalized);
  }
}

/// Byte cache size for [PlayerConfiguration] on player creation.
int bufferSizeBytesForSeconds(int seconds) =>
    PlayerBufferService.bufferSizeBytesForSeconds(seconds);
