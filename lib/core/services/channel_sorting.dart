import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';

/// Sorts live channels without changing the relevance order used by search.
List<Channel> sortChannels(Iterable<Channel> channels, ChannelSortMode mode) {
  final sorted = channels.toList(growable: false);
  final mutable = List<Channel>.from(sorted);
  mutable.sort((a, b) {
    final primary = switch (mode) {
      ChannelSortMode.providerDefault => a.providerOrder.compareTo(
        b.providerOrder,
      ),
      ChannelSortMode.alphabetical => _naturalCompare(
        a.name,
        b.name,
        caseInsensitive: true,
      ),
      ChannelSortMode.numeric => _compareChannelNumbers(a, b),
    };
    if (primary != 0) return primary;

    final nameCompare = _naturalCompare(a.name, b.name, caseInsensitive: true);
    if (nameCompare != 0) return nameCompare;

    final providerCompare = a.providerOrder.compareTo(b.providerOrder);
    if (providerCompare != 0) return providerCompare;
    return a.id.compareTo(b.id);
  });
  return mutable;
}

int _compareChannelNumbers(Channel a, Channel b) {
  final numberA = _parseChannelNumber(a.channelNumber);
  final numberB = _parseChannelNumber(b.channelNumber);
  if (numberA != null && numberB != null) {
    final numericCompare = numberA.compareTo(numberB);
    if (numericCompare != 0) return numericCompare;
    return _naturalCompare(
      a.channelNumber ?? '',
      b.channelNumber ?? '',
      caseInsensitive: true,
    );
  }
  if (numberA != null) return -1;
  if (numberB != null) return 1;
  return _naturalCompare(a.name, b.name, caseInsensitive: true);
}

double? _parseChannelNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed.isFinite ? parsed : null;
}

int _naturalCompare(
  String left,
  String right, {
  required bool caseInsensitive,
}) {
  final a = caseInsensitive ? left.toLowerCase() : left;
  final b = caseInsensitive ? right.toLowerCase() : right;
  final tokenPattern = RegExp(r'(\d+|\D+)');
  final aTokens = tokenPattern.allMatches(a).map((match) => match.group(0)!);
  final bTokens = tokenPattern.allMatches(b).map((match) => match.group(0)!);
  final aIterator = aTokens.iterator;
  final bIterator = bTokens.iterator;

  while (aIterator.moveNext() && bIterator.moveNext()) {
    final aToken = aIterator.current;
    final bToken = bIterator.current;
    final aNumber = int.tryParse(aToken);
    final bNumber = int.tryParse(bToken);
    final comparison = aNumber != null && bNumber != null
        ? aNumber.compareTo(bNumber)
        : aToken.compareTo(bToken);
    if (comparison != 0) return comparison;
  }

  if (aIterator.moveNext()) return 1;
  if (bIterator.moveNext()) return -1;
  return a.compareTo(b);
}
