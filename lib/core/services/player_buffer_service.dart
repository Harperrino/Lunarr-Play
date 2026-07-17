import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/live_stream_url.dart';

/// Applies mpv buffer, network and decode settings for live IPTV vs VOD playback.
abstract final class PlayerBufferService {
  static const int liveAnalyzeDurationSeconds = 5;
  static const int liveProbeSizeBytes = 5000000;
  static const int liveRecoveryAnalyzeDurationSeconds = 10;
  static const int liveRecoveryProbeSizeBytes = 10000000;

  /// Applies the playback profile for the current media type.
  ///
  /// For live playback, [preloadSeconds] is the user-facing startup target.
  /// The technical live cache is derived separately so the startup wait can be
  /// handled after a candidate stream has already settled.
  static Future<void> applyPlaybackProfile(
    Player player, {
    required bool isLive,
    required int preloadSeconds,
    LiveStreamDelivery liveDelivery = LiveStreamDelivery.continuous,
    bool liveStartupBuffer = false,
    bool vodAggressivePreload = false,
    int? liveAnalyzeDurationSecondsOverride,
    int? liveProbeSizeBytesOverride,
    String? liveDemuxerLavfFormatOverride,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      AppLogger.info(
        'PlayerBufferService: Native playback props skipped (non-native platform).',
      );
      return;
    }

    final clamped = preloadSeconds.clamp(3, 60).toInt();

    try {
      if (isLive) {
        final readAheadSeconds = liveTechnicalReadAheadSecondsForStartupSeconds(
          preloadSeconds,
        );
        await _applyLiveProfile(
          platform,
          readAheadSeconds,
          liveDelivery,
          liveStartupBuffer: liveStartupBuffer,
          liveAnalyzeDurationSecondsOverride:
              liveAnalyzeDurationSecondsOverride,
          liveProbeSizeBytesOverride: liveProbeSizeBytesOverride,
          liveDemuxerLavfFormatOverride: liveDemuxerLavfFormatOverride,
        );
      } else {
        await _applyVodProfile(
          platform,
          clamped,
          aggressivePreload: vodAggressivePreload,
          preparingOnly: vodAggressivePreload,
        );
      }

      final profileLabel = isLive
          ? (liveStartupBuffer ? 'Live startup buffer' : 'Live technical cache')
          : 'VOD preload';
      final appliedSeconds = isLive
          ? liveTechnicalReadAheadSecondsForStartupSeconds(preloadSeconds)
          : clamped;

      AppLogger.info(
        'PlayerBufferService: $profileLabel ${appliedSeconds}s applied.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'PlayerBufferService: Failed applying playback profile',
        e,
        stackTrace,
      );
    }
  }

  static Map<String, String> audioCompatibilityProperties({
    required bool forceStereo,
  }) {
    if (forceStereo) {
      return const {'audio-channels': 'stereo', 'ad-lavc-downmix': 'yes'};
    }

    return const {
      // Match mpv's default routing so disabling the setting restores the
      // prior behaviour as closely as possible.
      'audio-channels': 'auto-safe',
      'ad-lavc-downmix': 'no',
    };
  }

  static bool shouldForceMpegTsDemuxer(LiveStreamDelivery delivery) {
    return delivery == LiveStreamDelivery.continuous ||
        delivery == LiveStreamDelivery.tsSegment;
  }

  static String demuxerLavfFormatForDelivery(LiveStreamDelivery delivery) {
    if (delivery == LiveStreamDelivery.hls) return 'hls';
    return shouldForceMpegTsDemuxer(delivery) ? 'mpegts' : '';
  }

  static Map<String, String> liveDemuxerProperties({
    required LiveStreamDelivery delivery,
    int analyzeDurationSeconds = liveAnalyzeDurationSeconds,
    int probeSizeBytes = liveProbeSizeBytes,
    String? demuxerLavfFormatOverride,
  }) {
    return {
      'demuxer-lavf-analyzeduration': '$analyzeDurationSeconds',
      'demuxer-lavf-probesize': '$probeSizeBytes',
      'demuxer-lavf-format':
          demuxerLavfFormatOverride ?? demuxerLavfFormatForDelivery(delivery),
      // merge_pmt_versions keeps late/updated PMT audio PIDs (e.g. E-AC-3) instead
      // of treating them as a brand-new program without streams.
      'demuxer-lavf-o': 'merge_pmt_versions=1',
    };
  }

  /// Defensive per-profile resets for persistent mpv properties that only the
  /// live audio recovery path is allowed to set temporarily.
  static Map<String, String> playbackProfileResetProperties({
    required bool isLive,
  }) {
    return {
      // Forced audio decoder ('ad') must never leak into other channels/VOD.
      'ad': '',
      // mpv refuses .m3u8 candidates from memory playlists without this.
      'load-unsafe-playlists': isLive ? 'yes' : 'no',
    };
  }

  /// VOD/Series/Prep needs a clean lavf state so live-only demuxer settings do
  /// not carry over from the shared player instance.
  static Map<String, String> vodDemuxerResetProperties() {
    return {'demuxer-lavf-format': '', 'demuxer-lavf-o': ''};
  }

  static Future<void> _applyProfileResetProperties(
    NativePlayer platform, {
    required bool isLive,
  }) async {
    for (final entry in playbackProfileResetProperties(
      isLive: isLive,
    ).entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
      } catch (e) {
        // Bundled mpv may not know an option (e.g. load-unsafe-playlists) —
        // log and continue instead of aborting the rest of the profile.
        AppLogger.info(
          'PlayerBufferService: Skipped profile reset property ${entry.key}: $e',
        );
      }
    }
  }

  static Future<void> applyAudioCompatibility(
    Player player, {
    required bool forceStereo,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) {
      AppLogger.info(
        'PlayerBufferService: Audio compatibility skipped (non-native platform).',
      );
      return;
    }

    var appliedAny = false;
    for (final entry in audioCompatibilityProperties(
      forceStereo: forceStereo,
    ).entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
        appliedAny = true;
      } catch (e, stackTrace) {
        AppLogger.error(
          'PlayerBufferService: Failed setting audio compatibility property ${entry.key}',
          e,
          stackTrace,
        );
      }
    }

    if (appliedAny) {
      AppLogger.info(
        forceStereo
            ? 'Audio compatibility: force stereo enabled'
            : 'Audio compatibility: default audio channels',
      );
    }
  }

  static Future<void> _applyLiveProfile(
    NativePlayer platform,
    int readAheadSeconds,
    LiveStreamDelivery delivery, {
    bool liveStartupBuffer = false,
    int? liveAnalyzeDurationSecondsOverride,
    int? liveProbeSizeBytesOverride,
    String? liveDemuxerLavfFormatOverride,
  }) async {
    await _applyProfileResetProperties(platform, isLive: true);
    // Critical for continuous IPTV: never close on transient EOF, always reconnect.
    await platform.setProperty('keep-open', 'yes');
    await platform.setProperty('keep-open-pause', 'no');
    await platform.setProperty('loop-playlist', 'no');
    await platform.setProperty('loop-file', 'no');
    await platform.setProperty('cache-pause', 'no');
    await platform.setProperty(
      'cache-pause-initial',
      liveStartupBuffer ? 'yes' : 'no',
    );
    await platform.setProperty('demuxer-thread', 'yes');
    await platform.setProperty('network-timeout', '20');
    // Software decode - more tolerant of IPTV stream glitches than HW decoders on Windows.
    await platform.setProperty('hwdec', 'no');
    final liveDemuxerProps = liveDemuxerProperties(
      delivery: delivery,
      analyzeDurationSeconds:
          liveAnalyzeDurationSecondsOverride ?? liveAnalyzeDurationSeconds,
      probeSizeBytes: liveProbeSizeBytesOverride ?? liveProbeSizeBytes,
      demuxerLavfFormatOverride: liveDemuxerLavfFormatOverride,
    );
    await platform.setProperty(
      'demuxer-lavf-analyzeduration',
      liveDemuxerProps['demuxer-lavf-analyzeduration']!,
    );
    await platform.setProperty(
      'demuxer-lavf-probesize',
      liveDemuxerProps['demuxer-lavf-probesize']!,
    );
    // FFmpeg reconnect for transient HTTP drops - covers Dispatcharr proxy restarts.
    await platform.setProperty(
      'stream-lavf-o',
      'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
          'reconnect_on_http_error=4xx,5xx,reconnect_delay_max=5,'
          'multiple_requests=1,http_persistent=1,seekable=0',
    );

    await platform.setProperty(
      'demuxer-lavf-o',
      liveDemuxerProps['demuxer-lavf-o']!,
    );

    // Force MPEG-TS demuxer for raw continuous streams (Dispatcharr default).
    await platform.setProperty(
      'demuxer-lavf-format',
      liveDemuxerProps['demuxer-lavf-format']!,
    );

    await platform.setProperty('demuxer-readahead-secs', '$readAheadSeconds');
    await platform.setProperty('cache-secs', '$readAheadSeconds');
    // Hard cap - demuxer-cache-time can otherwise exceed cache-secs on live MPEG-TS.
    await platform.setProperty('demuxer-max-back-bytes', '0');
    await platform.setProperty(
      'demuxer-max-bytes',
      '${bufferSizeBytesForSeconds(readAheadSeconds)}',
    );
  }

  /// VOD needs a much larger read-ahead than live IPTV so scrubbing forward works.
  static const int vodCacheSeconds = 120;

  /// Target demuxer cache before starting VOD when pre-buffer is enabled.
  static const int vodPreBufferTargetSeconds = 90;

  /// Larger cache while preparing VOD for scrub-friendly playback.
  static const int vodPreBufferCacheSeconds = 180;

  static Future<void> _applyVodProfile(
    NativePlayer platform,
    int preloadSeconds, {
    bool aggressivePreload = false,
    bool preparingOnly = false,
  }) async {
    final cacheSecs = aggressivePreload
        ? vodPreBufferCacheSeconds
        : vodCacheSeconds;
    await _applyProfileResetProperties(platform, isLive: false);
    // mpv properties persist across loadfile on the shared player instance —
    // clear the live-only lavf options so they don't leak into VOD/series.
    for (final entry in vodDemuxerResetProperties().entries) {
      await platform.setProperty(entry.key, entry.value);
    }
    await platform.setProperty('loop-playlist', 'no');
    await platform.setProperty('loop-file', 'no');
    // cache-pause freezes on mid-file seeks until the demuxer refills at the
    // new position - logs showed seek "complete" while position stayed near 0.
    final cachePause = preparingOnly ? 'yes' : 'no';
    await platform.setProperty('cache-pause', cachePause);
    await platform.setProperty(
      'cache-pause-initial',
      preparingOnly ? 'yes' : 'no',
    );
    await platform.setProperty('hr-seek', 'yes');
    await platform.setProperty('force-seekable', 'yes');
    await platform.setProperty('cache-seeks', 'yes');
    await platform.setProperty('demuxer-thread', 'yes');
    await platform.setProperty('network-timeout', '30');
    await platform.setProperty('hwdec', 'auto');
    await platform.setProperty(
      'stream-lavf-o',
      'multiple_requests=1,http_persistent=1,seekable=1',
    );
    await platform.setProperty('demuxer-readahead-secs', '$cacheSecs');
    await platform.setProperty('cache-secs', '$cacheSecs');
    final maxBytes = (aggressivePreload ? 768 : 512) * 1024 * 1024;
    final maxBackBytes = (aggressivePreload ? 256 : 128) * 1024 * 1024;
    await platform.setProperty('demuxer-max-bytes', '$maxBytes');
    await platform.setProperty('demuxer-max-back-bytes', '$maxBackBytes');
  }

  /// After VOD prep, switch off cache-pause so scrubbing does not stall playback.
  static Future<void> applyVodPlaybackProfile(
    Player player, {
    required int preloadSeconds,
    bool aggressivePreload = false,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    await _applyVodProfile(
      platform,
      preloadSeconds,
      aggressivePreload: aggressivePreload,
      preparingOnly: false,
    );
  }

  /// Byte cache for [PlayerConfiguration] - ~2 MB/s to cover HD bitrates.
  ///
  /// Supports up to 120 s startup buffer for very stable streams; capped at
  /// ~256 MB to keep memory usage bounded on desktop.
  static int bufferSizeBytesForSeconds(int seconds) {
    final clamped = seconds.clamp(3, 120);
    return (clamped * 2 * 1024 * 1024).clamp(
      32 * 1024 * 1024,
      256 * 1024 * 1024,
    );
  }
}

/// Track-poll window for live streams: lavf needs the full analyzeduration of
/// real-time data before late audio PIDs (e.g. E-AC-3) appear, plus headroom.
/// Polling returns as soon as a track is found, so normal channels stay fast.
Duration liveTrackWaitTimeoutForAnalyzeSeconds(int analyzeSeconds) {
  return Duration(seconds: analyzeSeconds + 3);
}

/// Keeps a small technical live cache even when the user chooses "Off".
/// Supports the full 120 s startup-buffer range for stable streams.
int liveTechnicalReadAheadSecondsForStartupSeconds(int startupBufferSeconds) {
  if (startupBufferSeconds <= 0) return 3;
  return startupBufferSeconds.clamp(3, 120).toInt();
}

/// Standard headers for Xtream/Dispatcharr live proxies.
const Map<String, String> kLiveStreamHttpHeaders = {
  'User-Agent': 'mpv/0.36 m3uxtream_player',
  'Accept': '*/*',
};

/// HTTP headers for Xtream VOD - enables range-friendly progressive download.
const Map<String, String> kVodStreamHttpHeaders = {
  'User-Agent': 'mpv/0.36 m3uxtream_player',
  'Accept': '*/*',
};
