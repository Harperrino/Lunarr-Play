/// Stateless classification of media_kit stream errors.
class PlayerStreamErrorPolicy {
  const PlayerStreamErrorPolicy._();

  static bool isNonFatal(String error) {
    final lower = error.toLowerCase();
    return lower.contains('cannot seek') ||
        lower.contains('force-seekable') ||
        lower.contains('error decoding audio') ||
        lower.contains('decoding audio') ||
        lower.contains('audio decode error') ||
        lower.contains('non-existing pps') ||
        lower.contains('reference picture') ||
        lower.contains('packet corrupt') ||
        lower.contains('non-monotonous dts') ||
        lower.contains('decoding for stream') ||
        lower.contains('invalid data found') ||
        lower.contains('renderer') ||
        lower.contains('video renderer') ||
        lower.contains('video output') ||
        lower.contains('failed to initialize video output');
  }

  static bool isAudioDecodeWarning(String error) {
    final lower = error.toLowerCase();
    return lower.contains('error decoding audio') ||
        lower.contains('decoding audio') ||
        lower.contains('audio decode error');
  }

  static bool isOpenError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('failed to open') ||
        lower.contains('failed to recognize') ||
        lower.contains('no such file');
  }
}

/// Pure gate used before releasing a prepared live candidate.
class LiveAudioStabilizationPolicy {
  const LiveAudioStabilizationPolicy._();

  static bool shouldWait({
    required bool hasDecodedAudioInfo,
    required bool audioRecoveryWasNeeded,
    required bool initialAutoOnly,
    required bool hadNoAudioState,
    required bool trackSwitchedDuringPrep,
    required bool isDirectMpegTs,
  }) {
    return audioRecoveryWasNeeded ||
        initialAutoOnly ||
        trackSwitchedDuringPrep ||
        hadNoAudioState ||
        (isDirectMpegTs && !hasDecodedAudioInfo);
  }

  static String reason({
    required bool hasDecodedAudioInfo,
    required bool audioRecoveryWasNeeded,
    required bool initialAutoOnly,
    required bool hadNoAudioState,
    required bool trackSwitchedDuringPrep,
    required bool isDirectMpegTs,
  }) {
    if (audioRecoveryWasNeeded) return 'recovery';
    if (initialAutoOnly) return 'initial auto/no';
    if (trackSwitchedDuringPrep) return 'track switched';
    if (hadNoAudioState) return 'no-audio state';
    if (isDirectMpegTs && !hasDecodedAudioInfo) {
      return 'direct MPEG-TS risk';
    }
    return 'stable track fast path';
  }
}
