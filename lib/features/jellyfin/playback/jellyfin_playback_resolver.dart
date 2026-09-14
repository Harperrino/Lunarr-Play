import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_info.dart';

/// How a resolved stream is delivered.
enum JellyfinPlaybackMethod { directPlay, directStream, transcode }

/// Final playback input for the media player — the player never interprets
/// raw Jellyfin API responses.
class JellyfinResolvedPlayback {
  const JellyfinResolvedPlayback({
    required this.uri,
    required this.headers,
    required this.mediaSource,
    required this.playSessionId,
    required this.startPosition,
    required this.method,
  });

  final String uri;
  final Map<String, String> headers;
  final JellyfinMediaSource mediaSource;
  String get mediaSourceId => mediaSource.id;
  final String? playSessionId;
  final Duration startPosition;
  final JellyfinPlaybackMethod method;
}

class JellyfinPlaybackResolutionException implements Exception {
  const JellyfinPlaybackResolutionException(this.message);

  final String message;

  @override
  String toString() => 'JellyfinPlaybackResolutionException: $message';
}

/// Maps a [JellyfinPlaybackInfo] response onto a concrete stream for the
/// player. The order follows Jellyfin's playback decision: Direct Play,
/// Direct Stream/remux, then Transcoding.
class JellyfinPlaybackResolver {
  const JellyfinPlaybackResolver();

  JellyfinResolvedPlayback resolve({
    required String baseUrl,
    required String accessToken,
    required JellyfinItem item,
    required JellyfinPlaybackInfo playbackInfo,
    int? startTimeTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) {
    if (accessToken.isEmpty) {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin playback requires an access token.',
      );
    }

    JellyfinMediaSource? source;
    JellyfinPlaybackMethod? method;
    for (final candidate in playbackInfo.mediaSources) {
      if (candidate.supportsDirectPlay) {
        source = candidate;
        method = JellyfinPlaybackMethod.directPlay;
        break;
      }
    }
    if (method == null) {
      for (final candidate in playbackInfo.mediaSources) {
        if (candidate.supportsDirectStream && _hasTranscodingUrl(candidate)) {
          source = candidate;
          method = JellyfinPlaybackMethod.directStream;
          break;
        }
      }
    }
    if (method == null) {
      for (final candidate in playbackInfo.mediaSources) {
        if (candidate.supportsTranscoding && _hasTranscodingUrl(candidate)) {
          source = candidate;
          method = JellyfinPlaybackMethod.transcode;
          break;
        }
      }
    }
    if (source == null || method == null) {
      throw const JellyfinPlaybackResolutionException(
        'No usable Jellyfin playback URL is available.',
      );
    }

    final uri = switch (method) {
      JellyfinPlaybackMethod.directPlay => _directPlayUri(
        baseUrl: baseUrl,
        accessToken: accessToken,
        item: item,
        source: source,
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
      ),
      JellyfinPlaybackMethod.directStream => _serverPlaybackUri(
        baseUrl: baseUrl,
        accessToken: accessToken,
        source: source,
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
      ),
      JellyfinPlaybackMethod.transcode => _serverPlaybackUri(
        baseUrl: baseUrl,
        accessToken: accessToken,
        source: source,
        audioStreamIndex: audioStreamIndex,
        subtitleStreamIndex: subtitleStreamIndex,
      ),
    };

    final ticks = startTimeTicks ?? item.playbackPositionTicks;
    return JellyfinResolvedPlayback(
      uri: uri,
      headers: {'X-Emby-Token': accessToken},
      mediaSource: source,
      playSessionId: playbackInfo.playSessionId,
      startPosition: ticks > 0
          ? Duration(microseconds: ticks ~/ 10)
          : Duration.zero,
      method: method,
    );
  }

  bool _hasTranscodingUrl(JellyfinMediaSource source) {
    final url = source.transcodingUrl;
    return url != null && url.trim().isNotEmpty;
  }

  String _directPlayUri({
    required String baseUrl,
    required String accessToken,
    required JellyfinItem item,
    required JellyfinMediaSource source,
    required int? audioStreamIndex,
    required int? subtitleStreamIndex,
  }) {
    final base = _parseBaseUrl(baseUrl);
    final path = _appendBasePath(base, ['Videos', item.id, 'stream']);
    return _withPlaybackQuery(
      path,
      accessToken: accessToken,
      mediaSourceId: source.id,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      staticValue: 'true',
    ).toString();
  }

  String _serverPlaybackUri({
    required String baseUrl,
    required String accessToken,
    required JellyfinMediaSource source,
    required int? audioStreamIndex,
    required int? subtitleStreamIndex,
  }) {
    final rawUri = source.transcodingUrl?.trim();
    if (rawUri == null || rawUri.isEmpty) {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin selected a non-static stream but did not return a URL.',
      );
    }
    final uri = _resolveServerUrl(baseUrl, rawUri);
    if (uri.queryParameters['static']?.toLowerCase() == 'true') {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin returned a static URL for a non-static playback method.',
      );
    }
    return _withPlaybackQuery(
      uri,
      accessToken: accessToken,
      mediaSourceId: source.id,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
    ).toString();
  }

  Uri _parseBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin base URL is invalid.',
      );
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin base URL uses an unsupported scheme.',
      );
    }
    return uri;
  }

  Uri _resolveServerUrl(String baseUrl, String value) {
    final base = _parseBaseUrl(baseUrl);
    final raw = value.trim();
    if (raw.isEmpty) {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin returned an empty playback URL.',
      );
    }

    final parsedRaw = Uri.tryParse(raw);
    Uri? candidate;
    if (raw.startsWith('//')) {
      candidate = Uri.tryParse('${base.scheme}:$raw');
    } else if (parsedRaw?.hasScheme ?? false) {
      candidate = parsedRaw;
    } else if (parsedRaw != null) {
      candidate = _appendBasePath(
        base,
        parsedRaw.path
            .split('/')
            .where((segment) => segment.isNotEmpty)
            .toList(),
      ).replace(query: parsedRaw.query, fragment: parsedRaw.fragment);
    }

    if (candidate == null ||
        candidate.host.isEmpty ||
        candidate.userInfo.isNotEmpty) {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin returned an invalid playback URL.',
      );
    }
    if (!_sameOrigin(base, candidate)) {
      throw const JellyfinPlaybackResolutionException(
        'Jellyfin returned a playback URL outside the authenticated server.',
      );
    }
    return candidate;
  }

  Uri _appendBasePath(Uri base, List<String> segments) {
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final encodedSegments = segments.map(Uri.encodeComponent).join('/');
    return base.replace(path: '$basePath/$encodedSegments');
  }

  bool _sameOrigin(Uri expected, Uri actual) {
    return expected.scheme.toLowerCase() == actual.scheme.toLowerCase() &&
        expected.host.toLowerCase() == actual.host.toLowerCase() &&
        _effectivePort(expected) == _effectivePort(actual);
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return switch (uri.scheme.toLowerCase()) {
      'http' => 80,
      'https' => 443,
      _ => -1,
    };
  }

  Uri _withPlaybackQuery(
    Uri uri, {
    required String accessToken,
    required String mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String? staticValue,
  }) {
    final query = <String, dynamic>{};
    for (final entry in uri.queryParametersAll.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'api_key' ||
          key == 'audiostreamindex' ||
          key == 'subtitlestreamindex' ||
          key == 'mediasourceid' ||
          key == 'static') {
        continue;
      }
      query[entry.key] = entry.value;
    }
    query['api_key'] = accessToken;
    if (mediaSourceId.isNotEmpty) query['MediaSourceId'] = mediaSourceId;
    if (audioStreamIndex != null) {
      query['AudioStreamIndex'] = audioStreamIndex.toString();
    }
    if (subtitleStreamIndex != null) {
      query['SubtitleStreamIndex'] = subtitleStreamIndex.toString();
    }
    if (staticValue != null) query['static'] = staticValue;
    return uri.replace(queryParameters: query);
  }
}
