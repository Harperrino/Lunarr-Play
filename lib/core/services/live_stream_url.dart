import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';

/// Resolves live IPTV URLs for seamless continuous playback via Dispatcharr/Xtream.
abstract final class LiveStreamUrl {
  static final _liveExtensionPattern = RegExp(
    r'\.(ts|m3u8|mkv|mp4)$',
    caseSensitive: false,
  );

  /// Xtream/Dispatcharr continuous proxy — no file extension.
  /// See: `http://host/live/{user}/{pass}/{streamId}`
  static String continuousUrl(String streamUrl) {
    return streamUrl.trim().replaceFirst(_liveExtensionPattern, '');
  }

  /// Ordered candidates with the user-supplied URL first, then alternative formats.
  ///
  /// Dispatcharr/Xtream's `.ts` URL is a continuous MPEG-TS proxy, NOT a single segment file —
  /// mpv keeps the HTTP connection open and reads MPEG-TS packets indefinitely.
  /// `.m3u8` is segmented HLS and only works if the upstream actually provides HLS.
  static List<String> playbackCandidates(String streamUrl) {
    final trimmed = streamUrl.trim();
    final base = continuousUrl(trimmed);
    final seen = <String>{};
    final ordered = <String>[];

    void add(String url) {
      if (seen.add(url)) ordered.add(url);
    }

    add(trimmed);
    add('$base.ts');
    add(base);
    add('$base.m3u8');
    return ordered;
  }

  /// Ordered live fallback attempts with header profiles for diagnostics-aware retries.
  static List<StreamingFallbackAttempt> playbackAttempts(String streamUrl) {
    final trimmed = streamUrl.trim();
    final base = continuousUrl(trimmed);
    final candidates = <String>[trimmed, '$base.ts', base, '$base.m3u8'];
    final seen = <String>{};
    final attempts = <StreamingFallbackAttempt>[];

    void add(String playbackUrl, LiveStreamHeaderProfile headerProfile) {
      if (!seen.add('$playbackUrl|${headerProfile.name}')) return;
      attempts.add(
        StreamingFallbackAttempt(
          sourceUrl: trimmed,
          playbackUrl: playbackUrl,
          label:
              '${headerProfile.label} ${deliveryFor(trimmed).diagnosticLabel}->${deliveryFor(playbackUrl).diagnosticLabel}',
          headerProfile: headerProfile,
          deliveryType: deliveryFor(playbackUrl).diagnosticLabel,
        ),
      );
    }

    for (final playbackUrl in candidates) {
      add(playbackUrl, LiveStreamHeaderProfile.appMpv);
    }

    for (final playbackUrl in [trimmed, base, '$base.m3u8']) {
      add(playbackUrl, LiveStreamHeaderProfile.vlcLike);
    }

    for (final playbackUrl in [trimmed, '$base.m3u8']) {
      add(playbackUrl, LiveStreamHeaderProfile.browserLike);
    }

    return attempts;
  }

  static bool isLiveContainerUrl(String streamUrl) {
    final trimmed = streamUrl.trim();
    final lower = trimmed.toLowerCase();
    final uri = Uri.tryParse(trimmed);
    // Match the live proxy path against the URI path so query parameters
    // (e.g. tokens) do not break the Xtream/Dispatcharr pattern match.
    final path = uri?.path.toLowerCase() ?? lower;
    return lower.endsWith('.ts') ||
        lower.endsWith('.m3u8') ||
        _hasHlsHint(uri) ||
        _livePathPattern.hasMatch(path);
  }

  /// True for Xtream/Dispatcharr-style live proxy URLs that have no explicit
  /// file extension and are not HLS-hinted, e.g. `/live/{user}/{pass}/{id}`.
  static bool isExtensionlessContinuousLiveUrl(String streamUrl) {
    final trimmed = streamUrl.trim();
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('.ts') || lower.endsWith('.m3u8')) return false;
    return deliveryFor(trimmed) == LiveStreamDelivery.continuous &&
        isLiveContainerUrl(trimmed);
  }

  /// True when a [LiveStreamDelivery.tsSegment] candidate exists after
  /// [currentIndex] in the ordered fallback list.
  static bool hasLaterTsCandidate(
    List<StreamingFallbackAttempt> attempts,
    int currentIndex,
  ) {
    for (var i = currentIndex + 1; i < attempts.length; i++) {
      if (deliveryFor(attempts[i].playbackUrl) ==
          LiveStreamDelivery.tsSegment) {
        return true;
      }
    }
    return false;
  }

  static final _livePathPattern = RegExp(r'/live/[^/]+/[^/]+/\d+$');

  static LiveStreamDelivery deliveryFor(
    String playbackUrl, {
    bool? looksLikeHls,
  }) {
    if (looksLikeHls == true) return LiveStreamDelivery.hls;

    final lower = playbackUrl.toLowerCase();
    final uri = Uri.tryParse(playbackUrl.trim());
    if (_hasHlsHint(uri) || lower.endsWith('.m3u8')) {
      return LiveStreamDelivery.hls;
    }
    if (lower.endsWith('.ts')) return LiveStreamDelivery.tsSegment;
    return LiveStreamDelivery.continuous;
  }

  static bool _hasHlsHint(Uri? uri) {
    if (uri == null) return false;

    const hlsIndicators = {
      'm3u8',
      'hls',
      'application/vnd.apple.mpegurl',
      'application/x-mpegurl',
    };

    const hlsHintKeys = {
      'format',
      'output',
      'protocol',
      'type',
      'container',
      'ext',
    };

    for (final entry in uri.queryParameters.entries) {
      final key = entry.key.trim().toLowerCase();
      if (!hlsHintKeys.contains(key)) continue;

      final value = entry.value.trim().toLowerCase();
      if (hlsIndicators.contains(value)) return true;
    }

    return false;
  }
}

enum LiveStreamDelivery { continuous, hls, tsSegment }

extension LiveStreamDeliveryLabel on LiveStreamDelivery {
  String get diagnosticLabel => switch (this) {
    LiveStreamDelivery.continuous => 'continuous',
    LiveStreamDelivery.hls => 'hls',
    LiveStreamDelivery.tsSegment => 'ts',
  };
}
