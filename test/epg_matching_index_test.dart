import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';

/// Reference implementation of the previous linear matching behaviour. The
/// indexed implementation must return identical results for every case where
/// the documented match order applies.
String? _referenceResolve({
  required String name,
  required String? tvgId,
  required Set<String> knownEpgChannelIds,
  required Map<String, List<String>> displayNamesByChannelId,
}) {
  final idLookup = EpgMatchingService.buildCaseInsensitiveIdLookup(
    knownEpgChannelIds,
  );
  final displayNameEntries = <({String normalizedDisplay, String canonicalId})>[
    for (final entry in displayNamesByChannelId.entries)
      for (final displayName in entry.value)
        if (EpgMatchingService.normalizeName(displayName).isNotEmpty)
          (
            normalizedDisplay: EpgMatchingService.normalizeName(displayName),
            canonicalId: idLookup[entry.key.toLowerCase()] ?? entry.key,
          ),
  ];
  final normalizedKnownIds = {
    for (final id in knownEpgChannelIds)
      EpgMatchingService.normalizeName(id): id,
  };
  final tokenToIds = <String, List<String>>{};
  for (final epgId in knownEpgChannelIds) {
    for (final token in epgId.toLowerCase().split(RegExp(r'[.\s_\-]+'))) {
      if (token.length < 2) continue;
      tokenToIds.putIfAbsent(token, () => []).add(epgId);
    }
  }

  final normalizedTvgId = tvgId?.trim();
  if (normalizedTvgId != null && normalizedTvgId.isNotEmpty) {
    final exact = idLookup[normalizedTvgId.toLowerCase()];
    if (exact != null) return exact;
  }

  final displayNamesToTry = {
    name,
    EpgMatchingService.stripProviderPrefix(name),
  };
  for (final candidate in displayNamesToTry) {
    final normalizedChannelName = EpgMatchingService.normalizeName(candidate);
    if (normalizedChannelName.isEmpty) continue;
    for (final entry in displayNameEntries) {
      if (entry.normalizedDisplay == normalizedChannelName ||
          normalizedChannelName.contains(entry.normalizedDisplay) ||
          entry.normalizedDisplay.contains(normalizedChannelName)) {
        return entry.canonicalId;
      }
    }
  }

  final namesToTry = [name, EpgMatchingService.stripProviderPrefix(name)];
  for (final candidate in namesToTry) {
    final normalizedName = EpgMatchingService.normalizeName(candidate);
    if (normalizedName.isEmpty) continue;
    final exact = normalizedKnownIds[normalizedName];
    if (exact != null) return exact;
    for (final entry in normalizedKnownIds.entries) {
      final normalizedEpg = entry.key;
      if (normalizedEpg.isEmpty) continue;
      if (normalizedName.contains(normalizedEpg) ||
          normalizedEpg.contains(normalizedName) ||
          normalizedName.startsWith(normalizedEpg) ||
          normalizedEpg.startsWith(normalizedName)) {
        return entry.value;
      }
    }
    for (final tokenEntry in tokenToIds.entries) {
      final token = tokenEntry.key;
      if (token.length < 2) continue;
      if (normalizedName.contains(token)) {
        return tokenEntry.value.first;
      }
    }
  }
  return null;
}

void main() {
  group('EpgMatchingIndex indexed lookups', () {
    const knownIds = {
      'de.rtl',
      'de.rtl2',
      'de.rtlplus',
      'us.cnn',
      'uk.bbcone',
      'sky-sport-1',
      'sky-sport-2',
      'das_erste',
      'zdf.neo',
      'nick',
    };
    const displayNames = <String, List<String>>{
      'de.rtl': ['RTL HD', 'RTL Television'],
      'de.rtl2': ['RTL2', 'RTL II'],
      'uk.bbcone': ['BBC One', 'BBC1'],
      'das_erste': ['Das Erste', 'ARD'],
      'zdf.neo': ['ZDFneo'],
    };

    final cases = <(String name, String? tvgId)>[
      ('RTL HD', 'de.rtl'),
      ('RTL HD', 'DE.RTL'),
      ('RTL HD', 'wrong.id'),
      ('RTL HD', null),
      ('DE: RTL HD', null),
      ('RTL II', null),
      ('BBC One', null),
      ('DE: BBC One', null),
      ('Das Erste', null),
      ('ARD', null),
      ('ZDFneo', null),
      ('CNN', null),
      ('us cnn', null),
      ('sky sport 1', null),
      ('Sky Sport', null),
      ('Nickelodeon', null),
      ('nick', null),
      ('Unknown Station', null),
      ('Mystery Channel', 'xx.unknown'),
      ('', null),
      ('  ', '  '),
    ];

    test('returns the reference result for every corpus case', () {
      final index = EpgMatchingIndex(
        knownEpgChannelIds: knownIds,
        displayNamesByChannelId: displayNames,
      );
      for (final (name, tvgId) in cases) {
        final expected = _referenceResolve(
          name: name,
          tvgId: tvgId,
          knownEpgChannelIds: knownIds,
          displayNamesByChannelId: displayNames,
        );
        final actual = index
            .matchProjection(name: name, tvgId: tvgId)
            .resolvedEpgChannelId;
        expect(
          actual,
          expected,
          reason: 'mismatch for name="$name" tvgId="$tvgId"',
        );
      }
    });

    test(
      'fuzzy evaluations stay bounded by candidates, not catalogue size',
      () {
        final bigCatalog = <String>{
          for (var i = 0; i < 5000; i++) 'channel-$i.example',
          'de.rtl',
        };
        final index = EpgMatchingIndex(knownEpgChannelIds: bigCatalog);

        index.debugResetFuzzyEvaluations();
        final result = index.matchProjection(name: 'RTL HD', tvgId: null);

        expect(result.resolvedEpgChannelId, 'de.rtl');
        // A linear scan would evaluate thousands of candidates per channel.
        expect(index.debugFuzzyEvaluations, lessThan(200));
      },
    );

    test('one-character names never fall back to a catalogue scan', () {
      final bigCatalog = <String>{
        for (var i = 0; i < 10000; i++) 'sender-$i.example',
        'x',
      };
      final index = EpgMatchingIndex(knownEpgChannelIds: bigCatalog);

      expect(
        index.matchProjection(name: 'x', tvgId: null).resolvedEpgChannelId,
        'x',
        reason: 'the exact normalized-id map remains authoritative',
      );

      index.debugResetFuzzyEvaluations();
      expect(
        index.matchProjection(name: 'q', tvgId: null).resolvedEpgChannelId,
        isNull,
      );
      expect(index.debugFuzzyEvaluations, 0);
    });

    test('match cost is independent of catalogue size', () {
      final bigCatalog = <String>{
        for (var i = 0; i < 10000; i++) 'sender-$i.example',
        'de.rtl',
      };
      final index = EpgMatchingIndex(knownEpgChannelIds: bigCatalog);
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        index.matchProjection(name: 'RTL HD $i', tvgId: null);
      }
      stopwatch.stop();
      // 200 uncached matches against a 10k catalogue must stay comfortably
      // inside one UI frame budget even in the debug lane.
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
