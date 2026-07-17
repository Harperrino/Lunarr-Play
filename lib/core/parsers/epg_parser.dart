import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

/// Structured EPG Program Entry extracted from an XMLTV data source.
class ParsedEpgEntry {
  final String channelId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;

  ParsedEpgEntry({
    required this.channelId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
  });

  @override
  String toString() {
    return 'ParsedEpgEntry(channelId: $channelId, title: $title, startTime: $startTime, endTime: $endTime)';
  }
}

/// XMLTV channel definition — maps programme channel IDs to display names.
class ParsedEpgChannel {
  final String channelId;
  final String displayName;

  const ParsedEpgChannel({required this.channelId, required this.displayName});
}

/// Combined XMLTV parse result (programmes + channel catalogue).
class EpgParseResult {
  final List<ParsedEpgEntry> entries;
  final List<ParsedEpgChannel> channels;

  const EpgParseResult({required this.entries, required this.channels});
}

/// Highly-optimized streaming XMLTV EPG Parser.
/// Utilizes event-based SAX-like streaming (XmlEvent) to decompress, decode, and parse
/// gigabyte-sized EPG XML files on-the-fly with near-zero RAM footprint.
class EpgParser {
  /// Parses an XMLTV stream chunk-by-chunk.
  ///
  /// - If [isGzipped] is true, hooks a [gzip.decoder] to decompress the bytes on-the-fly.
  /// - Uses UTF-8 decoding to stream strings.
  /// - Extracts both `<channel>` display names and `<programme>` entries.
  static Future<EpgParseResult> parse({
    required Stream<List<int>> byteStream,
    required bool isGzipped,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'EpgParser: Beginning event-based streaming parsing (Decompress GZIP: $isGzipped)...',
    );

    final parsedEntries = <ParsedEpgEntry>[];
    final parsedChannels = <ParsedEpgChannel>[];

    final Stream<String> stringStream = isGzipped
        ? byteStream.transform(gzip.decoder).transform(utf8.decoder)
        : byteStream.transform(utf8.decoder);

    try {
      final xmlNodeStream = stringStream
          .toXmlEvents()
          .normalizeEvents()
          .selectSubtreeEvents(
            (event) => event.name == 'programme' || event.name == 'channel',
          )
          .toXmlNodes();

      await for (final nodes in xmlNodeStream) {
        for (final node in nodes) {
          if (node is! XmlElement) continue;

          if (node.name.local == 'channel') {
            _parseChannelElement(node, parsedChannels);
          } else if (node.name.local == 'programme') {
            _parseProgrammeElement(node, parsedEntries);
          }
        }
      }

      stopwatch.stop();
      AppLogger.info(
        'EpgParser: Completed parsing successfully. '
        'Extracted ${parsedEntries.length} programmes and ${parsedChannels.length} channel names '
        'in ${stopwatch.elapsedMilliseconds}ms.',
      );
      return EpgParseResult(entries: parsedEntries, channels: parsedChannels);
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.error(
        'EpgParser FATAL: Failed streaming and parsing XMLTV guide data!',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  static void _parseChannelElement(
    XmlElement node,
    List<ParsedEpgChannel> out,
  ) {
    final channelId = node.getAttribute('id')?.trim();
    if (channelId == null || channelId.isEmpty) return;

    for (final displayNameEl in node.findElements('display-name')) {
      final displayName = displayNameEl.innerText.trim();
      if (displayName.isEmpty) continue;
      out.add(ParsedEpgChannel(channelId: channelId, displayName: displayName));
    }
  }

  static void _parseProgrammeElement(
    XmlElement node,
    List<ParsedEpgEntry> out,
  ) {
    final startStr = node.getAttribute('start');
    final stopStr = node.getAttribute('stop');
    final channelId = node.getAttribute('channel')?.trim();

    if (startStr == null ||
        stopStr == null ||
        channelId == null ||
        channelId.isEmpty) {
      return;
    }

    final startTime = parseXmlTvDateTime(startStr);
    final endTime = parseXmlTvDateTime(stopStr);
    if (startTime == null || endTime == null) return;

    final titleElement = node.getElement('title');
    if (titleElement == null) return;
    final title = titleElement.innerText.trim();
    if (title.isEmpty) return;

    final descElement = node.getElement('desc');
    final desc = descElement?.innerText;

    out.add(
      ParsedEpgEntry(
        channelId: channelId,
        title: title,
        description: desc,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  /// Parses date/time strings commonly found in XMLTV formats.
  /// Supports both local time (yyyyMMddHHmmss) and timezone-offset times (yyyyMMddHHmmss +HHMM).
  static DateTime? parseXmlTvDateTime(String dateStr) {
    final clean = dateStr.trim();
    if (clean.length < 14) return null;

    try {
      final year = int.parse(clean.substring(0, 4));
      final month = int.parse(clean.substring(4, 6));
      final day = int.parse(clean.substring(6, 8));
      final hour = int.parse(clean.substring(8, 10));
      final minute = int.parse(clean.substring(10, 12));
      final second = int.parse(clean.substring(12, 14));

      var baseTime = DateTime(year, month, day, hour, minute, second);

      if (clean.length >= 20) {
        final tzPart = clean.substring(14).trim();
        if (tzPart.length == 5) {
          final sign = tzPart[0] == '-' ? -1 : 1;
          final tzHours = int.parse(tzPart.substring(1, 3));
          final tzMinutes = int.parse(tzPart.substring(3, 5));

          final utcTime = DateTime.utc(year, month, day, hour, minute, second);
          final offsetDuration =
              Duration(hours: tzHours, minutes: tzMinutes) * sign;
          final absoluteUtc = utcTime.subtract(offsetDuration);
          return absoluteUtc.toLocal();
        }
      }
      return baseTime;
    } catch (e) {
      AppLogger.warning(
        'EpgParser: Failed parsing XMLTV date-string "$dateStr": $e',
      );
      return null;
    }
  }
}
