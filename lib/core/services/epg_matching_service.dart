import 'package:m3uxtream_player/core/database/app_database.dart';

/// Result of matching a playlist channel against known EPG channel IDs.
enum EpgMatchStatus { matched, noTvgId, noMatch }

/// Result of matching one playlist channel to the EPG catalogue.
class EpgChannelMatchResult {
  const EpgChannelMatchResult({
    required this.matchStatus,
    this.resolvedEpgChannelId,
  });

  final EpgMatchStatus matchStatus;
  final String? resolvedEpgChannelId;
}

/// Pre-built lookup tables for fast repeated channel ↔ EPG matching.
class EpgMatchingIndex {
  EpgMatchingIndex({
    required Set<String> knownEpgChannelIds,
    Map<String, List<String>> displayNamesByChannelId = const {},
  }) : _knownEpgChannelIds = knownEpgChannelIds,
       _idLookup = EpgMatchingService.buildCaseInsensitiveIdLookup(
         knownEpgChannelIds,
       ),
       _displayNameEntries = _buildDisplayNameEntries(
         displayNamesByChannelId,
         EpgMatchingService.buildCaseInsensitiveIdLookup(knownEpgChannelIds),
       ),
       _normalizedKnownIds = {
         for (final id in knownEpgChannelIds)
           EpgMatchingService.normalizeName(id): id,
       },
       _tokenToIds = _buildTokenIndex(knownEpgChannelIds);

  final Set<String> _knownEpgChannelIds;
  final Map<String, String> _idLookup;
  final List<({String normalizedDisplay, String canonicalId})>
  _displayNameEntries;
  final Map<String, String> _normalizedKnownIds;
  final Map<String, List<String>> _tokenToIds;
  final Map<String, EpgChannelMatchResult> _matchCache = {};

  /// Number of memoized channel signatures retained for this index instance.
  int get memoizedMatchCount => _matchCache.length;

  /// Resolves and classifies [channel] in one pass.
  EpgChannelMatchResult matchChannel(Channel channel) {
    final cacheKey = _buildMatchCacheKey(channel);
    final cached = _matchCache[cacheKey];
    if (cached != null) return cached;

    final match = _matchChannelUncached(channel);
    _matchCache[cacheKey] = match;
    return match;
  }

  EpgChannelMatchResult _matchChannelUncached(Channel channel) {
    final resolvedId = _resolve(channel);
    if (resolvedId != null) {
      return EpgChannelMatchResult(
        matchStatus: EpgMatchStatus.matched,
        resolvedEpgChannelId: resolvedId,
      );
    }

    final tvgId = channel.tvgId?.trim();
    if (tvgId == null || tvgId.isEmpty) {
      return const EpgChannelMatchResult(matchStatus: EpgMatchStatus.noTvgId);
    }

    return const EpgChannelMatchResult(matchStatus: EpgMatchStatus.noMatch);
  }

  String _buildMatchCacheKey(Channel channel) {
    final trimmedTvgId = channel.tvgId?.trim().toLowerCase() ?? '';
    final normalizedName = EpgMatchingService.normalizeName(channel.name);
    final strippedName = EpgMatchingService.stripProviderPrefix(channel.name);
    final normalizedStrippedName = EpgMatchingService.normalizeName(
      strippedName,
    );
    return '$trimmedTvgId|$normalizedName|$normalizedStrippedName';
  }

  String? _resolve(Channel channel) {
    if (_knownEpgChannelIds.isEmpty && _displayNameEntries.isEmpty) return null;

    final tvgId = channel.tvgId?.trim();
    if (tvgId != null && tvgId.isNotEmpty) {
      final exact = _idLookup[tvgId.toLowerCase()];
      if (exact != null) return exact;
    }

    final byDisplayName = _resolveByDisplayName(channel.name);
    if (byDisplayName != null) return byDisplayName;

    return _resolveByNameFallback(channel.name);
  }

  String? _resolveByDisplayName(String channelName) {
    final namesToTry = {
      channelName,
      EpgMatchingService.stripProviderPrefix(channelName),
    };

    for (final name in namesToTry) {
      final normalizedChannelName = EpgMatchingService.normalizeName(name);
      if (normalizedChannelName.isEmpty) continue;

      for (final entry in _displayNameEntries) {
        if (entry.normalizedDisplay == normalizedChannelName ||
            normalizedChannelName.contains(entry.normalizedDisplay) ||
            entry.normalizedDisplay.contains(normalizedChannelName)) {
          return entry.canonicalId;
        }
      }
    }

    return null;
  }

  String? _resolveByNameFallback(String channelName) {
    final namesToTry = [
      channelName,
      EpgMatchingService.stripProviderPrefix(channelName),
    ];
    for (final name in namesToTry) {
      final match = _resolveByNameFallbackSingle(name);
      if (match != null) return match;
    }
    return null;
  }

  String? _resolveByNameFallbackSingle(String channelName) {
    final normalizedName = EpgMatchingService.normalizeName(channelName);
    if (normalizedName.isEmpty) return null;

    final exact = _normalizedKnownIds[normalizedName];
    if (exact != null) return exact;

    for (final entry in _normalizedKnownIds.entries) {
      final normalizedEpg = entry.key;
      if (normalizedEpg.isEmpty) continue;

      if (normalizedName.contains(normalizedEpg) ||
          normalizedEpg.contains(normalizedName) ||
          normalizedName.startsWith(normalizedEpg) ||
          normalizedEpg.startsWith(normalizedName)) {
        return entry.value;
      }
    }

    for (final tokenEntry in _tokenToIds.entries) {
      final token = tokenEntry.key;
      if (token.length < 2) continue;
      if (normalizedName.contains(token)) {
        return tokenEntry.value.first;
      }
    }

    return null;
  }

  static List<({String normalizedDisplay, String canonicalId})>
  _buildDisplayNameEntries(
    Map<String, List<String>> displayNamesByChannelId,
    Map<String, String> idLookup,
  ) {
    final entries = <({String normalizedDisplay, String canonicalId})>[];
    for (final entry in displayNamesByChannelId.entries) {
      final canonicalId = idLookup[entry.key.toLowerCase()] ?? entry.key;
      for (final displayName in entry.value) {
        final normalizedDisplay = EpgMatchingService.normalizeName(displayName);
        if (normalizedDisplay.isEmpty) continue;
        entries.add((
          normalizedDisplay: normalizedDisplay,
          canonicalId: canonicalId,
        ));
      }
    }
    return entries;
  }

  static Map<String, List<String>> _buildTokenIndex(
    Set<String> knownEpgChannelIds,
  ) {
    final index = <String, List<String>>{};
    for (final epgId in knownEpgChannelIds) {
      for (final token in epgId.toLowerCase().split(RegExp(r'[.\s_\-]+'))) {
        if (token.length < 2) continue;
        index.putIfAbsent(token, () => []).add(epgId);
      }
    }
    return index;
  }
}

/// Pure EPG channel-ID resolution — no Flutter or Riverpod dependencies.
class EpgMatchingService {
  EpgMatchingService._();

  /// Normalizes a label for loose comparison: lowercase, trim, strip non-alphanumerics.
  static String normalizeName(String input) {
    return input.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Strips common IPTV country prefixes, e.g. `DE: 3sat HD` → `3sat HD`.
  static String stripProviderPrefix(String channelName) {
    final trimmed = channelName.trim();
    final match = RegExp(r'^[A-Za-z]{2}\s*:\s*(.+)$').firstMatch(trimmed);
    if (match != null) return match.group(1)!.trim();
    return trimmed;
  }

  /// Builds a case-insensitive lookup map for XMLTV channel IDs.
  static Map<String, String> buildCaseInsensitiveIdLookup(
    Set<String> knownEpgChannelIds,
  ) {
    final lookup = <String, String>{};
    for (final id in knownEpgChannelIds) {
      lookup[id.toLowerCase()] = id;
    }
    return lookup;
  }

  /// Resolves the XMLTV channel ID for a playlist [channel], or null when no match exists.
  static String? resolveEpgChannelId({
    required Channel channel,
    required Set<String> knownEpgChannelIds,
    Map<String, List<String>> displayNamesByChannelId = const {},
  }) {
    return EpgMatchingIndex(
      knownEpgChannelIds: knownEpgChannelIds,
      displayNamesByChannelId: displayNamesByChannelId,
    ).matchChannel(channel).resolvedEpgChannelId;
  }

  /// Classifies how well [channel] matches the cached EPG data set.
  static EpgMatchStatus classifyMatch({
    required Channel channel,
    required Set<String> knownEpgChannelIds,
    Map<String, List<String>> displayNamesByChannelId = const {},
  }) {
    return EpgMatchingIndex(
      knownEpgChannelIds: knownEpgChannelIds,
      displayNamesByChannelId: displayNamesByChannelId,
    ).matchChannel(channel).matchStatus;
  }
}
