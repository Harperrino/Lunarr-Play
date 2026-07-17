import 'dart:convert';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/parsers/m3u_parser.dart';

/// One playable episode parsed from Xtream `get_series_info`.
class ParsedSeriesEpisode {
  const ParsedSeriesEpisode({
    required this.episodeId,
    required this.title,
    required this.streamUrl,
    this.season,
    this.episodeNum,
    this.durationSecs,
  });

  final String episodeId;
  final String title;
  final String streamUrl;
  final int? season;
  final int? episodeNum;
  final int? durationSecs;
}

/// Payload for parsing all Xtream catalogue JSON in a background isolate.
class XtreamCataloguePayload {
  const XtreamCataloguePayload({
    required this.liveStreamsJson,
    required this.liveCategoriesJson,
    required this.vodStreamsJson,
    required this.vodCategoriesJson,
    required this.seriesJson,
    required this.seriesCategoriesJson,
    required this.host,
    required this.username,
    required this.password,
  });

  final String liveStreamsJson;
  final String liveCategoriesJson;
  final String vodStreamsJson;
  final String vodCategoriesJson;
  final String seriesJson;
  final String seriesCategoriesJson;
  final String host;
  final String username;
  final String password;
}

/// Service responsible for decoding and parsing raw Xtream Codes JSON payloads.
class XtreamParser {
  /// Parses live + VOD + series catalogues into a single channel list.
  static List<ParsedChannel> parseFullCatalogue(
    XtreamCataloguePayload payload,
  ) {
    final live = parseLiveStreams(
      streamsJsonStr: payload.liveStreamsJson,
      categoriesJsonStr: payload.liveCategoriesJson,
      host: payload.host,
      username: payload.username,
      password: payload.password,
    );
    final vod = parseVodStreams(
      streamsJsonStr: payload.vodStreamsJson,
      categoriesJsonStr: payload.vodCategoriesJson,
      host: payload.host,
      username: payload.username,
      password: payload.password,
    );
    final series = parseSeries(
      seriesJsonStr: payload.seriesJson,
      categoriesJsonStr: payload.seriesCategoriesJson,
      host: payload.host,
      username: payload.username,
      password: payload.password,
    );

    return [...live, ...vod, ...series];
  }

  /// Decodes categories and live stream JSON strings.
  static List<ParsedChannel> parseLiveStreams({
    required String streamsJsonStr,
    required String categoriesJsonStr,
    required String host,
    required String username,
    required String password,
  }) {
    return _parseStreamCatalogue(
      streamsJsonStr: streamsJsonStr,
      categoriesJsonStr: categoriesJsonStr,
      host: host,
      username: username,
      password: password,
      channelType: 'live',
      idField: 'stream_id',
      buildStreamUrl: (normalizedHost, streamId, stream) {
        return '$normalizedHost/live/$username/$password/$streamId';
      },
      logoFields: const ['stream_icon'],
    );
  }

  /// Decodes VOD (movie) streams.
  static List<ParsedChannel> parseVodStreams({
    required String streamsJsonStr,
    required String categoriesJsonStr,
    required String host,
    required String username,
    required String password,
  }) {
    return _parseStreamCatalogue(
      streamsJsonStr: streamsJsonStr,
      categoriesJsonStr: categoriesJsonStr,
      host: host,
      username: username,
      password: password,
      channelType: 'vod',
      idField: 'stream_id',
      buildStreamUrl: (normalizedHost, streamId, stream) {
        final ext = stream['container_extension']?.toString().trim();
        final safeExt = (ext == null || ext.isEmpty) ? 'mp4' : ext;
        return '$normalizedHost/movie/$username/$password/$streamId.$safeExt';
      },
      logoFields: const ['stream_icon'],
    );
  }

  /// Decodes series catalogue rows (episodes loaded lazily via [parseSeriesInfo]).
  static List<ParsedChannel> parseSeries({
    required String seriesJsonStr,
    required String categoriesJsonStr,
    required String host,
    required String username,
    required String password,
  }) {
    final stopwatch = Stopwatch()..start();
    final channels = <ParsedChannel>[];
    final normalizedHost = _normalizeHostForStream(host);

    try {
      final seriesList = _decodeJsonArray(seriesJsonStr, label: 'series');
      final categoryMap = _buildCategoryMap(categoriesJsonStr);

      for (var i = 0; i < seriesList.length; i++) {
        final entry = seriesList[i];
        if (entry is! Map<String, dynamic>) continue;

        try {
          final seriesId = entry['series_id']?.toString();
          if (seriesId == null || seriesId.isEmpty) {
            AppLogger.warning(
              'XtreamParser: Skipped series at index $i — missing series_id.',
            );
            continue;
          }

          final name = entry['name']?.toString() ?? 'Unknown Series';
          final logo = _firstNonEmptyString(entry, const [
            'cover',
            'stream_icon',
          ]);
          final categoryId = entry['category_id']?.toString();
          final groupName = categoryId != null ? categoryMap[categoryId] : null;

          channels.add(
            ParsedChannel(
              name: name,
              streamUrl: '$normalizedHost/series/$username/$password/$seriesId',
              tvgLogo: logo,
              groupName: groupName,
              channelType: 'series',
              streamId: seriesId,
            ),
          );
        } catch (e, stackTrace) {
          AppLogger.warning(
            'XtreamParser: Failed parsing series entry at index $i. Skipping. Error: $e',
            null,
            stackTrace,
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'XtreamParser FATAL: Failed decoding series JSON!',
        e,
        stackTrace,
      );
      rethrow;
    }

    stopwatch.stop();
    AppLogger.info(
      'XtreamParser: Parsed ${channels.length} series in ${stopwatch.elapsedMilliseconds}ms.',
    );
    return channels;
  }

  /// Parses `get_series_info` JSON into playable episodes (M6C lazy load).
  static List<ParsedSeriesEpisode> parseSeriesInfo({
    required String seriesInfoJsonStr,
    required String host,
    required String username,
    required String password,
  }) {
    final normalizedHost = _normalizeHostForStream(host);
    final episodes = <ParsedSeriesEpisode>[];

    try {
      final decoded = jsonDecode(seriesInfoJsonStr);
      if (decoded is! Map<String, dynamic>) return episodes;

      final episodesMap = decoded['episodes'];
      if (episodesMap is! Map<String, dynamic>) return episodes;

      for (final seasonEntry in episodesMap.entries) {
        final seasonNum = int.tryParse(seasonEntry.key);
        final seasonList = seasonEntry.value;
        if (seasonList is! List<dynamic>) continue;

        for (final item in seasonList) {
          if (item is! Map<String, dynamic>) continue;

          final episodeId = item['id']?.toString();
          if (episodeId == null || episodeId.isEmpty) continue;

          final title = item['title']?.toString() ?? 'Episode';
          final ext = item['container_extension']?.toString().trim();
          final safeExt = (ext == null || ext.isEmpty) ? 'mp4' : ext;
          final episodeNum = int.tryParse(
            item['episode_num']?.toString() ?? '',
          );
          final durationSecs = int.tryParse(item['duration']?.toString() ?? '');

          episodes.add(
            ParsedSeriesEpisode(
              episodeId: episodeId,
              title: title,
              streamUrl:
                  '$normalizedHost/series/$username/$password/$episodeId.$safeExt',
              season: seasonNum,
              episodeNum: episodeNum,
              durationSecs: durationSecs,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'XtreamParser FATAL: Failed decoding series info JSON!',
        e,
        stackTrace,
      );
      rethrow;
    }

    episodes.sort((a, b) {
      final seasonCompare = (a.season ?? 0).compareTo(b.season ?? 0);
      if (seasonCompare != 0) return seasonCompare;
      return (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0);
    });

    return episodes;
  }

  static List<ParsedChannel> _parseStreamCatalogue({
    required String streamsJsonStr,
    required String categoriesJsonStr,
    required String host,
    required String username,
    required String password,
    required String channelType,
    required String idField,
    required String Function(
      String normalizedHost,
      String streamId,
      Map<String, dynamic> stream,
    )
    buildStreamUrl,
    required List<String> logoFields,
  }) {
    final stopwatch = Stopwatch()..start();
    final channels = <ParsedChannel>[];
    final normalizedHost = _normalizeHostForStream(host);

    try {
      final streamsList = _decodeJsonArray(streamsJsonStr, label: channelType);
      final categoryMap = _buildCategoryMap(categoriesJsonStr);

      for (var i = 0; i < streamsList.length; i++) {
        final stream = streamsList[i];
        if (stream is! Map<String, dynamic>) continue;

        try {
          final streamId = stream[idField]?.toString();
          if (streamId == null || streamId.isEmpty) {
            AppLogger.warning(
              'XtreamParser: Skipped $channelType entry at index $i — missing $idField.',
            );
            continue;
          }

          final name = stream['name']?.toString() ?? 'Unknown';
          final logo = _firstNonEmptyString(stream, logoFields);
          final tvgId = stream['epg_channel_id']?.toString();
          final categoryId = stream['category_id']?.toString();
          final groupName = categoryId != null ? categoryMap[categoryId] : null;

          channels.add(
            ParsedChannel(
              name: name,
              streamUrl: buildStreamUrl(normalizedHost, streamId, stream),
              tvgId: tvgId == null || tvgId.isEmpty ? null : tvgId,
              tvgName: tvgId == null || tvgId.isEmpty ? null : tvgId,
              tvgLogo: logo,
              groupName: groupName,
              channelType: channelType,
              streamId: streamId,
            ),
          );
        } catch (e, stackTrace) {
          AppLogger.warning(
            'XtreamParser: Failed parsing $channelType entry at index $i. Skipping. Error: $e',
            null,
            stackTrace,
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'XtreamParser FATAL: Failed decoding $channelType JSON!',
        e,
        stackTrace,
      );
      rethrow;
    }

    stopwatch.stop();
    AppLogger.info(
      'XtreamParser: Parsed ${channels.length} $channelType entries in ${stopwatch.elapsedMilliseconds}ms.',
    );
    return channels;
  }

  static List<dynamic> _decodeJsonArray(
    String jsonStr, {
    required String label,
  }) {
    if (jsonStr.trim().isEmpty) return const [];

    final decoded = jsonDecode(jsonStr);
    if (decoded is! List<dynamic>) {
      throw FormatException(
        'XtreamParser: Expected JSON array for $label catalogue.',
      );
    }
    return decoded;
  }

  static Map<String, String> _buildCategoryMap(String categoriesJsonStr) {
    final map = <String, String>{};
    if (categoriesJsonStr.trim().isEmpty) return map;

    final decoded = jsonDecode(categoriesJsonStr);
    if (decoded is! List<dynamic>) return map;

    for (final cat in decoded) {
      if (cat is Map<String, dynamic>) {
        final id = cat['category_id']?.toString();
        final name = cat['category_name']?.toString();
        if (id != null && name != null) {
          map[id] = name;
        }
      }
    }
    return map;
  }

  static String? _firstNonEmptyString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _normalizeHostForStream(String host) {
    var url = host.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
