import 'package:flutter/foundation.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';

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

/// Insertion-ordered candidate store with an n-gram narrowing index.
///
/// Fuzzy substring checks only ever run on candidates sharing at least one
/// 2- or 3-character gram with the query (plus the tiny always-checked set of
/// keys shorter than three characters). Substring containment always implies
/// a shared gram, so narrowing never changes match results — it only removes
/// full-catalogue scans. Keys of length one cannot be narrowed and fall back
/// to an ordered full scan.
class _FuzzyIndex {
  final List<String> _keys = <String>[];
  final Map<String, List<int>> _grams = <String, List<int>>{};

  static const int _gramMin = 2;
  static const int _gramMax = 3;

  static Iterable<String> ngramsOf(String value) sync* {
    if (value.length < _gramMax) {
      yield value;
      return;
    }
    for (var i = 0; i + _gramMin <= value.length; i++) {
      yield value.substring(i, i + _gramMin);
    }
    for (var i = 0; i + _gramMax <= value.length; i++) {
      yield value.substring(i, i + _gramMax);
    }
  }

  void add(String key) {
    final index = _keys.length;
    _keys.add(key);
    // One-character values remain available through the exact lookup maps,
    // but are intentionally not fuzzy candidates: they have no meaningful
    // shared token and would otherwise force a whole-catalogue scan.
    if (key.length < _gramMin) {
      return;
    }
    for (final gram in ngramsOf(key)) {
      (_grams[gram] ??= <int>[]).add(index);
    }
  }

  /// Candidate key indexes in original insertion order.
  List<int> candidates(String query) {
    if (query.length < _gramMin) {
      return const <int>[];
    }
    final hits = <int>{};
    for (final gram in ngramsOf(query)) {
      final list = _grams[gram];
      if (list != null) hits.addAll(list);
    }
    return hits.toList()..sort();
  }

  String operator [](int index) => _keys[index];

  int get length => _keys.length;
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
       _normalizedKnownIds = {
         for (final id in knownEpgChannelIds)
           EpgMatchingService.normalizeName(id): id,
       } {
    final displayNameEntries = _buildDisplayNameEntries(
      displayNamesByChannelId,
      _idLookup,
    );
    _displayNameEntries = displayNameEntries;
    _displayNameExact = <String, String>{};
    for (final entry in displayNameEntries) {
      _displayNameExact.putIfAbsent(
        entry.normalizedDisplay,
        () => entry.canonicalId,
      );
      _displayNameFuzzy.add(entry.normalizedDisplay);
    }
    for (final entry in _normalizedKnownIds.entries) {
      _knownIdFuzzy.add(entry.key);
    }
    _knownIdList = _normalizedKnownIds.entries.toList(growable: false);
    _tokenFirstId = <String>[];
    _tokenFuzzy = _FuzzyIndex();
    for (final entry in _buildTokenIndex(knownEpgChannelIds).entries) {
      _tokenFuzzy.add(entry.key);
      _tokenFirstId.add(entry.value.first);
    }
  }

  final Set<String> _knownEpgChannelIds;
  final Map<String, String> _idLookup;
  late final List<({String normalizedDisplay, String canonicalId})>
  _displayNameEntries;
  late final Map<String, String> _displayNameExact;
  final _FuzzyIndex _displayNameFuzzy = _FuzzyIndex();
  final Map<String, String> _normalizedKnownIds;
  final _FuzzyIndex _knownIdFuzzy = _FuzzyIndex();
  late final List<MapEntry<String, String>> _knownIdList;
  late final _FuzzyIndex _tokenFuzzy;
  late final List<String> _tokenFirstId;
  final Map<String, EpgChannelMatchResult> _matchCache = {};
  int _debugFuzzyEvaluations = 0;

  /// Number of memoized channel signatures retained for this index instance.
  int get memoizedMatchCount => _matchCache.length;

  /// Fuzzy predicate evaluations performed since the last reset. Tests use
  /// this to prove matching never scans the whole EPG catalogue.
  @visibleForTesting
  int get debugFuzzyEvaluations => _debugFuzzyEvaluations;

  @visibleForTesting
  void debugResetFuzzyEvaluations() => _debugFuzzyEvaluations = 0;

  /// Resolves and classifies [channel] in one pass.
  EpgChannelMatchResult matchChannel(Channel channel) {
    return _match(name: channel.name, tvgId: channel.tvgId);
  }

  /// Resolves a projection-only search row without materializing a [Channel].
  EpgChannelMatchResult matchCatalogEntry(SearchCatalogEntry entry) {
    return _match(name: entry.name, tvgId: entry.epgChannelId);
  }

  /// Resolves a lightweight visible-row projection without a [Channel].
  EpgChannelMatchResult matchProjection({required String name, String? tvgId}) {
    return _match(name: name, tvgId: tvgId);
  }

  EpgChannelMatchResult _match({required String name, String? tvgId}) {
    final cacheKey = _buildMatchCacheKey(name: name, tvgId: tvgId);
    final cached = _matchCache[cacheKey];
    if (cached != null) return cached;

    final match = _matchUncached(name: name, tvgId: tvgId);
    _matchCache[cacheKey] = match;
    return match;
  }

  EpgChannelMatchResult _matchUncached({required String name, String? tvgId}) {
    final resolvedId = _resolve(name: name, tvgId: tvgId);
    if (resolvedId != null) {
      return EpgChannelMatchResult(
        matchStatus: EpgMatchStatus.matched,
        resolvedEpgChannelId: resolvedId,
      );
    }

    final normalizedTvgId = tvgId?.trim();
    if (normalizedTvgId == null || normalizedTvgId.isEmpty) {
      return const EpgChannelMatchResult(matchStatus: EpgMatchStatus.noTvgId);
    }

    return const EpgChannelMatchResult(matchStatus: EpgMatchStatus.noMatch);
  }

  String _buildMatchCacheKey({required String name, String? tvgId}) {
    final trimmedTvgId = tvgId?.trim().toLowerCase() ?? '';
    final normalizedName = EpgMatchingService.normalizeName(name);
    final strippedName = EpgMatchingService.stripProviderPrefix(name);
    final normalizedStrippedName = EpgMatchingService.normalizeName(
      strippedName,
    );
    return '$trimmedTvgId|$normalizedName|$normalizedStrippedName';
  }

  /// Match order (unchanged contract):
  /// 1. exact `tvgId`,
  /// 2. exact normalized display name,
  /// 3. narrowed display-name candidates,
  /// 4. exact normalized id/name,
  /// 5. narrowed token fallback.
  String? _resolve({required String name, String? tvgId}) {
    if (_knownEpgChannelIds.isEmpty && _displayNameEntries.isEmpty) {
      return null;
    }

    final normalizedTvgId = tvgId?.trim();
    if (normalizedTvgId != null && normalizedTvgId.isNotEmpty) {
      final exact = _idLookup[normalizedTvgId.toLowerCase()];
      if (exact != null) return exact;
    }

    final byDisplayName = _resolveByDisplayName(name);
    if (byDisplayName != null) return byDisplayName;

    return _resolveByNameFallback(name);
  }

  String? _resolveByDisplayName(String channelName) {
    final namesToTry = {
      channelName,
      EpgMatchingService.stripProviderPrefix(channelName),
    };

    for (final name in namesToTry) {
      final normalizedChannelName = EpgMatchingService.normalizeName(name);
      if (normalizedChannelName.isEmpty) continue;

      final exact = _displayNameExact[normalizedChannelName];
      if (exact != null) return exact;

      for (final index in _displayNameFuzzy.candidates(normalizedChannelName)) {
        _debugFuzzyEvaluations++;
        final entry = _displayNameEntries[index];
        if (normalizedChannelName.contains(entry.normalizedDisplay) ||
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

    for (final index in _knownIdFuzzy.candidates(normalizedName)) {
      _debugFuzzyEvaluations++;
      final entry = _knownIdList[index];
      final normalizedEpg = entry.key;
      if (normalizedEpg.isEmpty) continue;
      if (normalizedName.contains(normalizedEpg) ||
          normalizedEpg.contains(normalizedName)) {
        return entry.value;
      }
    }

    for (final index in _tokenFuzzy.candidates(normalizedName)) {
      _debugFuzzyEvaluations++;
      final token = _tokenFuzzy[index];
      if (normalizedName.contains(token)) {
        return _tokenFirstId[index];
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
