import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';

final RegExp _naturalTokenPattern = RegExp(r'(\d+|\D+)');

/// Uses the imported provider order when present and the stable database ID
/// for legacy rows that still carry schema-v6's default value of zero.
int effectiveChannelProviderOrder(Channel channel) {
  return channel.providerOrder == 0 ? channel.id : channel.providerOrder;
}

/// Sorts live channels without changing the relevance order used by search.
///
/// All comparison keys are prepared once per invocation. In particular, the
/// natural-sort regexp and channel-number parse never run inside the sort
/// comparator, which keeps large catalogue resorting bounded by the list sort
/// itself rather than repeated temporary allocations.
List<Channel> sortChannels(Iterable<Channel> channels, ChannelSortMode mode) {
  final prepared = channels.map(_PreparedChannel.new).toList(growable: true);
  prepared.sort((a, b) {
    final primary = switch (mode) {
      ChannelSortMode.providerDefault => a.effectiveProviderOrder.compareTo(
        b.effectiveProviderOrder,
      ),
      ChannelSortMode.alphabetical => a.nameKey.compareTo(b.nameKey),
      ChannelSortMode.numeric => _compareChannelNumbers(a, b),
    };
    if (primary != 0) return primary;

    final nameCompare = a.nameKey.compareTo(b.nameKey);
    if (nameCompare != 0) return nameCompare;

    final providerCompare = a.effectiveProviderOrder.compareTo(
      b.effectiveProviderOrder,
    );
    if (providerCompare != 0) return providerCompare;
    return a.channel.id.compareTo(b.channel.id);
  });
  return prepared.map((entry) => entry.channel).toList(growable: false);
}

int _compareChannelNumbers(_PreparedChannel a, _PreparedChannel b) {
  final numberA = a.parsedChannelNumber;
  final numberB = b.parsedChannelNumber;
  if (numberA != null && numberB != null) {
    final numericCompare = numberA.compareTo(numberB);
    if (numericCompare != 0) return numericCompare;
    return a.channelNumberKey.compareTo(b.channelNumberKey);
  }
  if (numberA != null) return -1;
  if (numberB != null) return 1;
  return a.nameKey.compareTo(b.nameKey);
}

double? _parseChannelNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) return null;
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed.isFinite ? parsed : null;
}

class _PreparedChannel {
  _PreparedChannel(this.channel)
    : effectiveProviderOrder = effectiveChannelProviderOrder(channel),
      nameKey = _NaturalSortKey(channel.name),
      channelNumberKey = _NaturalSortKey(channel.channelNumber ?? ''),
      parsedChannelNumber = _parseChannelNumber(channel.channelNumber);

  final Channel channel;
  final int effectiveProviderOrder;
  final _NaturalSortKey nameKey;
  final _NaturalSortKey channelNumberKey;
  final double? parsedChannelNumber;
}

class _NaturalSortKey {
  _NaturalSortKey(String value) {
    final normalizedValue = value.toLowerCase();
    normalized = normalizedValue;
    tokens = [
      for (final match in _naturalTokenPattern.allMatches(normalizedValue))
        _NaturalToken(match.group(0)!),
    ];
  }

  late final String normalized;
  late final List<_NaturalToken> tokens;

  int compareTo(_NaturalSortKey other) {
    final length = tokens.length < other.tokens.length
        ? tokens.length
        : other.tokens.length;
    for (var index = 0; index < length; index++) {
      final left = tokens[index];
      final right = other.tokens[index];
      final comparison = left.compareTo(right);
      if (comparison != 0) return comparison;
    }

    if (tokens.length != other.tokens.length) {
      return tokens.length.compareTo(other.tokens.length);
    }
    return normalized.compareTo(other.normalized);
  }
}

class _NaturalToken {
  _NaturalToken(this.value) : number = int.tryParse(value);

  final String value;
  final int? number;

  int compareTo(_NaturalToken other) {
    final leftNumber = number;
    final rightNumber = other.number;
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    return value.compareTo(other.value);
  }
}
