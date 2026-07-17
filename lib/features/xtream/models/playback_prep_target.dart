import 'package:m3uxtream_player/core/database/app_database.dart';

/// VOD movie or series episode queued for the pre-buffer prep screen.
class PlaybackPrepTarget {
  const PlaybackPrepTarget({
    required this.playbackChannel,
    required this.streamUrl,
    this.startPosition = Duration.zero,
    this.posterUrl,
    this.subtitle,
    this.isSeries = false,
  });

  final Channel playbackChannel;
  final String streamUrl;
  final Duration startPosition;
  final String? posterUrl;
  final String? subtitle;
  final bool isSeries;
}
