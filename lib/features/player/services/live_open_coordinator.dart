import 'package:media_kit/media_kit.dart';

import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/core/services/live_audio_track_service.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';

/// Immutable identity for one concrete playback attempt.
///
/// [sourceUrl] is the stable database/user URL. [playbackUrl] is the effective
/// candidate passed to media_kit and may differ because of delivery fallback.
final class PlaybackAttemptContext {
  const PlaybackAttemptContext({
    required this.sourceUrl,
    required this.playbackUrl,
    required this.sessionToken,
  });

  final String sourceUrl;
  final String playbackUrl;
  final int sessionToken;
}

final class LiveOpenPlan {
  const LiveOpenPlan({
    required this.sourceUrl,
    required this.sourceDelivery,
    required this.attempts,
  });

  final String sourceUrl;
  final LiveStreamDelivery sourceDelivery;
  final List<StreamingFallbackAttempt> attempts;
}

/// Owns live candidate planning and fallback-only decisions.
///
/// The notifier still executes player I/O and publishes Riverpod state. This
/// keeps the extraction behavior-neutral while giving source and effective
/// playback URLs explicit, non-interchangeable roles.
final class LiveOpenCoordinator {
  const LiveOpenCoordinator();

  LiveOpenPlan createPlan({
    required String sourceUrl,
    required bool autoFallbackEnabled,
  }) {
    final normalizedSource = sourceUrl.trim();
    final allAttempts = LiveStreamUrl.playbackAttempts(normalizedSource);
    return LiveOpenPlan(
      sourceUrl: normalizedSource,
      sourceDelivery: LiveStreamUrl.deliveryFor(normalizedSource),
      attempts: autoFallbackEnabled
          ? allAttempts.toList(growable: true)
          : allAttempts.take(1).toList(growable: false),
    );
  }

  PlaybackAttemptContext attemptContext({
    required LiveOpenPlan plan,
    required String playbackUrl,
    required int sessionToken,
  }) {
    return PlaybackAttemptContext(
      sourceUrl: plan.sourceUrl,
      playbackUrl: playbackUrl,
      sessionToken: sessionToken,
    );
  }

  bool shouldRunDeferredHlsProbe({
    required bool autoFallbackEnabled,
    required bool alreadyChecked,
    required LiveStreamDelivery sourceDelivery,
    required String sourceUrl,
    required List<StreamingFallbackAttempt> attempts,
    required int currentIndex,
  }) {
    if (!autoFallbackEnabled || alreadyChecked) return false;
    if (sourceDelivery != LiveStreamDelivery.continuous) return false;
    if (!LiveStreamUrl.isExtensionlessContinuousLiveUrl(sourceUrl)) {
      return false;
    }
    if (currentIndex <= 0 || currentIndex >= attempts.length) return false;

    return attempts[currentIndex - 1].headerProfile ==
            LiveStreamHeaderProfile.appMpv &&
        attempts[currentIndex].headerProfile != LiveStreamHeaderProfile.appMpv;
  }

  StreamingFallbackAttempt deferredHlsAttemptFor(String sourceUrl) {
    return StreamingFallbackAttempt(
      sourceUrl: sourceUrl,
      playbackUrl: sourceUrl,
      label: 'App/mpv deferred-hls',
      headerProfile: LiveStreamHeaderProfile.appMpv,
      deliveryType: LiveStreamDelivery.hls.diagnosticLabel,
    );
  }

  bool shouldQuickSwitchToTsDeliveryCandidate({
    required bool canSeek,
    required LiveStreamDelivery delivery,
    required String playbackUrl,
    required List<AudioTrack> rawTracks,
    required List<AudioTrack> selectableTracks,
    required bool hasStreamError,
    required bool hasLaterTsCandidate,
  }) {
    if (canSeek) return false;
    if (delivery != LiveStreamDelivery.continuous) return false;
    if (!LiveStreamUrl.isExtensionlessContinuousLiveUrl(playbackUrl)) {
      return false;
    }
    if (selectableTracks.isNotEmpty) return false;
    if (rawTracks.isEmpty ||
        !rawTracks.every(LiveAudioTrackService.isSpecialTrack)) {
      return false;
    }
    if (hasStreamError) return false;
    if (!hasLaterTsCandidate) return false;
    return true;
  }

  bool isQuickSwitchStructurallyEligible({
    required bool canSeek,
    required LiveStreamDelivery delivery,
    required String playbackUrl,
    required List<StreamingFallbackAttempt> attempts,
    required int currentIndex,
  }) {
    return !canSeek &&
        delivery == LiveStreamDelivery.continuous &&
        LiveStreamUrl.isExtensionlessContinuousLiveUrl(playbackUrl) &&
        LiveStreamUrl.hasLaterTsCandidate(attempts, currentIndex);
  }
}
