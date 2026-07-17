import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';

/// Whether VOD should be pre-buffered before playback starts.
final vodPreBufferEnabledProvider =
    AsyncNotifierProvider<VodPreBufferEnabledNotifier, bool>(
      VodPreBufferEnabledNotifier.new,
    );

class VodPreBufferEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(appStateRepositoryProvider).getVodPreBufferEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(appStateRepositoryProvider).setVodPreBufferEnabled(enabled);
    state = AsyncData(enabled);
  }
}

/// Target demuxer cache (seconds) before VOD prep playback starts.
final vodPreBufferTargetSecondsProvider =
    AsyncNotifierProvider<VodPreBufferTargetSecondsNotifier, int>(
      VodPreBufferTargetSecondsNotifier.new,
    );

class VodPreBufferTargetSecondsNotifier extends AsyncNotifier<int> {
  static const defaultSeconds = 90;

  @override
  Future<int> build() async {
    return ref
        .read(appStateRepositoryProvider)
        .getVodPreBufferTargetSeconds(defaultSeconds: defaultSeconds);
  }

  Future<void> setSeconds(int seconds) async {
    final clamped = seconds.clamp(15, 300);
    await ref
        .read(appStateRepositoryProvider)
        .setVodPreBufferTargetSeconds(clamped);
    state = AsyncData(clamped);
  }
}
