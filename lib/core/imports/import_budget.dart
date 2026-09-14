import 'dart:convert';

import 'package:m3uxtream_player/core/imports/import_cancellation.dart';
import 'package:m3uxtream_player/core/imports/import_limit_exception.dart';
import 'package:m3uxtream_player/core/imports/import_limits.dart';

enum ImportRecordKind { record, line, channel, category }

/// Mutable counters owned by one import orchestrator.
///
/// All checks allow the exact limit and fail on the first byte/row beyond it.
class ImportBudget {
  final ImportLimits limits;
  final ImportCancellation cancellation;
  final DateTime startedAt;

  int transportBytes = 0;
  int decodedBytes = 0;
  int records = 0;
  int lineRecords = 0;
  int channelRecords = 0;
  int categoryRecords = 0;
  int persistedRows = 0;
  final Map<String, int> _endpointBytes = {};

  ImportBudget({
    required this.limits,
    ImportCancellation? cancellation,
    DateTime? startedAt,
  }) : cancellation = cancellation ?? ImportCancellation(),
       startedAt = startedAt ?? DateTime.now();

  void consumeTransportBytes(
    int count, {
    required String phase,
    String? endpoint,
  }) {
    cancellation.throwIfCancelled();
    _checkDuration(phase);
    transportBytes += count;
    _enforce(
      code: ImportLimitCode.transportBytes,
      phase: phase,
      actual: transportBytes,
      limit: limits.maxTransportBytes,
    );
    if (endpoint != null) {
      final endpointTotal = (_endpointBytes[endpoint] ?? 0) + count;
      _endpointBytes[endpoint] = endpointTotal;
      _enforce(
        code: ImportLimitCode.endpointTransportBytes,
        phase: phase,
        actual: endpointTotal,
        limit: limits.maxEndpointTransportBytes,
      );
    }
  }

  void consumeDecodedBytes(int count, {required String phase}) {
    cancellation.throwIfCancelled();
    _checkDuration(phase);
    decodedBytes += count;
    _enforce(
      code: ImportLimitCode.decodedBytes,
      phase: phase,
      actual: decodedBytes,
      limit: limits.maxDecodedBytes,
    );
  }

  void acceptRecord(
    ImportRecordKind kind, {
    int count = 1,
    required String phase,
  }) {
    cancellation.throwIfCancelled();
    _checkDuration(phase);
    switch (kind) {
      case ImportRecordKind.record:
        records += count;
        _enforce(
          code: ImportLimitCode.records,
          phase: phase,
          actual: records,
          limit: limits.maxRecords,
        );
        return;
      case ImportRecordKind.line:
        lineRecords += count;
        _enforce(
          code: ImportLimitCode.lineRecords,
          phase: phase,
          actual: lineRecords,
          limit: limits.maxLineRecords,
        );
        return;
      case ImportRecordKind.channel:
        channelRecords += count;
        _enforce(
          code: ImportLimitCode.channelRecords,
          phase: phase,
          actual: channelRecords,
          limit: limits.maxChannelRecords,
        );
        return;
      case ImportRecordKind.category:
        categoryRecords += count;
        _enforce(
          code: ImportLimitCode.categoryRecords,
          phase: phase,
          actual: categoryRecords,
          limit: limits.maxCategoryRecords,
        );
        return;
    }
  }

  void checkField(String value, {required String phase}) {
    cancellation.throwIfCancelled();
    final size = utf8.encode(value).length;
    _enforce(
      code: ImportLimitCode.fieldBytes,
      phase: phase,
      actual: size,
      limit: limits.maxFieldBytes,
    );
  }

  void acceptPersistedRows(int count, {required String phase}) {
    cancellation.throwIfCancelled();
    _checkDuration(phase);
    persistedRows += count;
    _enforce(
      code: ImportLimitCode.persistedRows,
      phase: phase,
      actual: persistedRows,
      limit: limits.maxPersistedRows,
    );
  }

  void checkXmlDepth(int depth, {required String phase}) {
    _enforce(
      code: ImportLimitCode.xmlDepth,
      phase: phase,
      actual: depth,
      limit: limits.maxXmlDepth,
    );
  }

  void checkpoint(String phase) {
    cancellation.throwIfCancelled();
    _checkDuration(phase);
  }

  void _checkDuration(String phase) {
    final elapsed = DateTime.now().difference(startedAt);
    _enforce(
      code: ImportLimitCode.duration,
      phase: phase,
      actual: elapsed.inMilliseconds,
      limit: limits.maxDuration.inMilliseconds,
    );
  }

  void _enforce({
    required ImportLimitCode code,
    required String phase,
    required int actual,
    required int limit,
  }) {
    if (actual <= limit) return;
    final error = ImportLimitException(
      code: code,
      phase: phase,
      actual: actual,
      limit: limit,
    );
    cancellation.cancel(error);
    throw error;
  }
}
