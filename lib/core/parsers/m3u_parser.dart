import 'dart:convert';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/m3u_channel_type_classifier.dart';

/// Data class representing a parsed channel from an M3U/M3U8 playlist.
class ParsedChannel {
  final String name;
  final String streamUrl;
  final String? tvgId;
  final String? tvgName;
  final String? tvgLogo;
  final String? groupName;
  final String channelType; // 'live', 'vod', 'series'
  final String? streamId; // Optional identifier for Xtream Codes

  const ParsedChannel({
    required this.name,
    required this.streamUrl,
    this.tvgId,
    this.tvgName,
    this.tvgLogo,
    this.groupName,
    required this.channelType,
    this.streamId,
  });

  @override
  String toString() {
    return 'ParsedChannel(name: $name, type: $channelType, group: $groupName, url: $streamUrl)';
  }
}

/// A high-efficiency, line-by-line M3U/M3U8 parser designed to handle
/// huge playlist files (50MB+) without causing RAM spikes or UI lag.
class M3uParser {
  /// Extracts `url-tvg="..."` from the `#EXTM3U` header line, if present.
  static String? extractEpgUrl(String content) {
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toUpperCase().startsWith('#EXTM3U')) {
        return _extractHeaderAttribute(trimmed, 'url-tvg');
      }
      if (!trimmed.startsWith('#')) break;
    }
    return null;
  }

  static String? _extractHeaderAttribute(String headerLine, String key) {
    final regex = RegExp(
      '$key\\s*=\\s*(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\\s]+))',
      caseSensitive: false,
    );
    final match = regex.firstMatch(headerLine);
    if (match != null) {
      return match.group(1) ?? match.group(2) ?? match.group(3);
    }
    return null;
  }

  /// Parses M3U content string and returns a list of [ParsedChannel] objects.
  /// This operation is optimized for O(N) parsing in a single pass.
  static List<ParsedChannel> parse(String content) {
    final stopwatch = Stopwatch()..start();
    final List<ParsedChannel> channels = [];

    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) {
      AppLogger.warning('M3uParser: Empty content provided.');
      return channels;
    }

    AppLogger.info(
      'M3uParser: Starting line-by-line parsing of ${lines.length} lines...',
    );

    bool hasM3uHeader = false;
    // Step 1: Verify header presence
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toUpperCase().startsWith('#EXTM3U')) {
        hasM3uHeader = true;
        break;
      }
      // If we see a non-comment line before #EXTM3U, it might not be a valid M3U file
      if (!trimmed.startsWith('#')) {
        break;
      }
    }

    if (!hasM3uHeader) {
      AppLogger.warning(
        'M3uParser: Content does not start with #EXTM3U. Proceeding with caution.',
      );
    }

    String? currentExtInfLine;
    String? currentExtGrp; // Fallback category from #EXTGRP

    // Step 2: Single-pass parsing loop
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.toUpperCase().startsWith('#EXTINF:')) {
        currentExtInfLine = line;
        currentExtGrp = null; // Reset group for the next channel
      } else if (line.toUpperCase().startsWith('#EXTGRP:')) {
        currentExtGrp = line.substring(8).trim();
      } else if (!line.startsWith('#')) {
        // Line is a stream URL
        if (currentExtInfLine != null) {
          try {
            final channel = _parseChannelItem(
              currentExtInfLine,
              line,
              currentExtGrp,
            );
            if (channel != null) {
              channels.add(channel);
            }
          } catch (e, stackTrace) {
            // Defensive error handling: log and skip corrupt lines
            AppLogger.warning(
              'M3uParser: Failed parsing channel at line ${i + 1} due to corrupt metadata! Skipping entry. Error: $e',
              null,
              stackTrace,
            );
          }
          currentExtInfLine = null;
          currentExtGrp = null;
        }
      }
    }

    stopwatch.stop();
    AppLogger.info(
      'M3uParser: Successfully parsed ${channels.length} channels from M3U in ${stopwatch.elapsedMilliseconds}ms.',
    );
    return channels;
  }

  /// Extracts metadata from an individual `#EXTINF` line and its corresponding URL.
  static ParsedChannel? _parseChannelItem(
    String extInfLine,
    String url,
    String? extGrpGroup,
  ) {
    if (url.isEmpty) return null;

    // Robust attribute extraction using our specialized RegEx helper
    final tvgId = _extractAttribute(extInfLine, 'tvg-id');
    final tvgName = _extractAttribute(extInfLine, 'tvg-name');
    final tvgLogo = _extractAttribute(extInfLine, 'tvg-logo');

    // Group name extraction (group-title attribute takes precedence over #EXTGRP)
    var groupName = _extractAttribute(extInfLine, 'group-title') ?? extGrpGroup;
    if (groupName != null && groupName.trim().isEmpty) {
      groupName = null;
    }

    // Extract display name (everything after the comma)
    final name = _parseChannelName(extInfLine);

    // Auto-classify channel category ('live', 'vod', 'series')
    final channelType = M3uChannelTypeClassifier.classify(
      url: url,
      name: name,
      groupName: groupName,
    );

    return ParsedChannel(
      name: name,
      streamUrl: url,
      tvgId: tvgId,
      tvgName: tvgName,
      tvgLogo: tvgLogo,
      groupName: groupName,
      channelType: channelType,
    );
  }

  /// Robustly extracts an attribute value from the `#EXTINF` line using RegEx.
  /// Handles double quotes, single quotes, and unquoted values seamlessly.
  static String? _extractAttribute(String line, String key) {
    final regex = RegExp(
      '$key\\s*=\\s*(?:"([^"]*)"|\x27([^\x27]*)\x27|([^\\s,\\b]+))',
      caseSensitive: false,
    );
    final match = regex.firstMatch(line);
    if (match != null) {
      return match.group(1) ?? match.group(2) ?? match.group(3);
    }
    return null;
  }

  /// Parses the channel display name from the `#EXTINF` line.
  /// Ignores commas inside quoted attribute blocks by tracking quote state.
  static String _parseChannelName(String line) {
    final extinfIndex = line.toUpperCase().indexOf('#EXTINF:');
    if (extinfIndex == -1) return 'Unknown Channel';

    final content = line.substring(extinfIndex + '#EXTINF:'.length);

    int commaIndex = -1;
    bool inDoubleQuotes = false;
    bool inSingleQuotes = false;

    // Scan character-by-character to locate the real separating comma
    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"' && !inSingleQuotes) {
        inDoubleQuotes = !inDoubleQuotes;
      } else if (char == "'" && !inDoubleQuotes) {
        inSingleQuotes = !inSingleQuotes;
      } else if (char == ',' && !inDoubleQuotes && !inSingleQuotes) {
        commaIndex = i;
        break;
      }
    }

    if (commaIndex != -1) {
      final name = content.substring(commaIndex + 1).trim();
      return name.isEmpty ? 'Unknown Channel' : name;
    }

    // Fallback search for last comma if standard scanning fails
    final lastComma = content.lastIndexOf(',');
    if (lastComma != -1) {
      final name = content.substring(lastComma + 1).trim();
      return name.isEmpty ? 'Unknown Channel' : name;
    }

    return 'Unknown Channel';
  }
}
