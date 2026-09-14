/// Stable, source-free limit identifiers suitable for diagnostics and UI.
enum ImportLimitCode {
  transportBytes('IMPORT_TRANSPORT_BYTES_LIMIT'),
  endpointTransportBytes('IMPORT_ENDPOINT_BYTES_LIMIT'),
  decodedBytes('IMPORT_DECODED_BYTES_LIMIT'),
  records('IMPORT_RECORDS_LIMIT'),
  lineRecords('IMPORT_LINES_LIMIT'),
  channelRecords('IMPORT_CHANNEL_RECORDS_LIMIT'),
  categoryRecords('IMPORT_CATEGORY_RECORDS_LIMIT'),
  fieldBytes('IMPORT_FIELD_BYTES_LIMIT'),
  persistedRows('IMPORT_PERSISTED_ROWS_LIMIT'),
  xmlDepth('IMPORT_XML_DEPTH_LIMIT'),
  duration('IMPORT_DURATION_LIMIT'),
  cancelled('IMPORT_CANCELLED');

  final String diagnosticCode;
  const ImportLimitCode(this.diagnosticCode);
}

class ImportLimitException implements Exception {
  final ImportLimitCode code;
  final String phase;
  final int actual;
  final int limit;

  const ImportLimitException({
    required this.code,
    required this.phase,
    required this.actual,
    required this.limit,
  });

  /// Safe for logs and user-visible error boundaries: no source or raw data.
  @override
  String toString() =>
      '${code.diagnosticCode} during $phase (actual: $actual, limit: $limit)';
}
