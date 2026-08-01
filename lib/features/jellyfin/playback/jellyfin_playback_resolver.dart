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
    required this.mediaSourceId,
    required this.playSessionId,
    required this.startPosition,
    required this.method,
  });

  final String uri;
  final Map<String, String> headers;
  final String mediaSourceId;
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
/// player. Wave 4 only resolves Direct Play; Direct Stream and Transcoding
/// are deliberately not activated yet.
class JellyfinPlaybackResolver {
  const JellyfinPlaybackResolver();

  JellyfinResolvedPlayback resolve({
    required String baseUrl,
    required String accessToken,
    required JellyfinItem item,
    required JellyfinPlaybackInfo playbackInfo,
  }) {
    JellyfinMediaSource? directSource;
    for (final source in playbackInfo.mediaSources) {
      if (source.supportsDirectPlay) {
        directSource = source;
        break;
      }
    }
    if (directSource == null) {
      throw const JellyfinPlaybackResolutionException(
        'No direct-play media source is available.',
      );
    }

    final uri =
        '$baseUrl/Videos/${item.id}/stream'
        '?static=true&MediaSourceId=${directSource.id}'
        '&api_key=$accessToken';

    return JellyfinResolvedPlayback(
      uri: uri,
      headers: {'X-Emby-Token': accessToken},
      mediaSourceId: directSource.id,
      playSessionId: playbackInfo.playSessionId,
      startPosition: item.playbackPositionTicks > 0
          ? Duration(microseconds: item.playbackPositionTicks ~/ 10)
          : Duration.zero,
      method: JellyfinPlaybackMethod.directPlay,
    );
  }
}
