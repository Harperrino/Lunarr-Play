import 'dart:isolate';

import 'package:m3uxtream_player/core/api/xtream_client.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';

/// Loads series episodes — Xtream API or direct M3U stream fallback.
class SeriesEpisodeService {
  /// True when [channel] has a directly playable stream (M3U-style series).
  static bool isDirectPlaySeries(Channel channel) {
    final url = channel.streamUrl.trim();
    if (url.isEmpty) return false;

    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.m3u8') ||
        lower.endsWith('.ts') ||
        lower.contains('/movie/')) {
      return true;
    }

    // Xtream catalogue placeholder: …/series/{user}/{pass}/{seriesId} (no file extension).
    return !RegExp(r'/series/[^/]+/[^/]+/[^/.]+$').hasMatch(lower);
  }

  Future<List<ParsedSeriesEpisode>> loadEpisodes({
    required Channel seriesChannel,
    required Playlist playlist,
  }) async {
    if (isDirectPlaySeries(seriesChannel)) {
      AppLogger.info(
        'SeriesEpisodeService: Direct-play series "${seriesChannel.name}" (no episode API).',
      );
      return [
        ParsedSeriesEpisode(
          episodeId: seriesChannel.streamId ?? seriesChannel.id.toString(),
          title: seriesChannel.name,
          streamUrl: seriesChannel.streamUrl,
        ),
      ];
    }

    final seriesId = seriesChannel.streamId;
    if (seriesId == null || seriesId.isEmpty) {
      throw StateError(
        'Series "${seriesChannel.name}" has no stream ID for episode lookup.',
      );
    }

    if (playlist.type != 'xtream') {
      throw StateError('Episode lookup requires an Xtream playlist.');
    }

    final username = playlist.username;
    final password = playlist.password;
    if (username == null || password == null) {
      throw StateError('Xtream credentials missing for series episode lookup.');
    }

    final json = await XtreamClient.fetchSeriesInfo(
      host: playlist.urlOrHost,
      username: username,
      password: password,
      seriesId: seriesId,
    );

    return Isolate.run(() {
      return XtreamParser.parseSeriesInfo(
        seriesInfoJsonStr: json,
        host: playlist.urlOrHost,
        username: username,
        password: password,
      );
    });
  }
}
