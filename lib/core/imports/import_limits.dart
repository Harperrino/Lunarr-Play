/// Finite resource ceilings for one logical import.
class ImportLimits {
  final int maxTransportBytes;
  final int maxEndpointTransportBytes;
  final int maxDecodedBytes;
  final int maxRecords;
  final int maxLineRecords;
  final int maxChannelRecords;
  final int maxCategoryRecords;
  final int maxFieldBytes;
  final int maxPersistedRows;
  final int maxXmlDepth;
  final Duration maxDuration;

  const ImportLimits({
    required this.maxTransportBytes,
    required this.maxEndpointTransportBytes,
    required this.maxDecodedBytes,
    required this.maxRecords,
    required this.maxLineRecords,
    required this.maxChannelRecords,
    required this.maxCategoryRecords,
    required this.maxFieldBytes,
    required this.maxPersistedRows,
    required this.maxXmlDepth,
    required this.maxDuration,
  });
}
