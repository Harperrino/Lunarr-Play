import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/imports/import_budget.dart';
import 'package:m3uxtream_player/core/imports/import_cancellation.dart';
import 'package:m3uxtream_player/core/imports/import_limit_exception.dart';
import 'package:m3uxtream_player/core/imports/import_limits.dart';

ImportLimits _limits({
  int transport = 3,
  int endpoint = 3,
  int decoded = 3,
  int records = 3,
  int lines = 3,
  int channels = 3,
  int categories = 3,
  int field = 3,
  int persisted = 3,
  int depth = 3,
  Duration duration = const Duration(minutes: 1),
}) {
  return ImportLimits(
    maxTransportBytes: transport,
    maxEndpointTransportBytes: endpoint,
    maxDecodedBytes: decoded,
    maxRecords: records,
    maxLineRecords: lines,
    maxChannelRecords: channels,
    maxCategoryRecords: categories,
    maxFieldBytes: field,
    maxPersistedRows: persisted,
    maxXmlDepth: depth,
    maxDuration: duration,
  );
}

void main() {
  test('each counter accepts limit - 1 and exact limit, then fails closed', () {
    final transport = ImportBudget(limits: _limits());
    transport.consumeTransportBytes(2, phase: 'transport', endpoint: 'one');
    transport.consumeTransportBytes(1, phase: 'transport', endpoint: 'one');
    expect(
      () => transport.consumeTransportBytes(
        1,
        phase: 'transport',
        endpoint: 'two',
      ),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.transportBytes,
        ),
      ),
    );

    final endpoint = ImportBudget(limits: _limits(transport: 9));
    endpoint.consumeTransportBytes(2, phase: 'endpoint', endpoint: 'one');
    endpoint.consumeTransportBytes(1, phase: 'endpoint', endpoint: 'one');
    expect(
      () => endpoint.consumeTransportBytes(
        1,
        phase: 'endpoint',
        endpoint: 'one',
      ),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.endpointTransportBytes,
        ),
      ),
    );

    final decoded = ImportBudget(limits: _limits());
    decoded.consumeDecodedBytes(2, phase: 'decode');
    decoded.consumeDecodedBytes(1, phase: 'decode');
    expect(
      () => decoded.consumeDecodedBytes(1, phase: 'decode'),
      throwsA(isA<ImportLimitException>()),
    );

    for (final kind in ImportRecordKind.values) {
      final recordsBudget = ImportBudget(limits: _limits());
      recordsBudget.acceptRecord(kind, count: 2, phase: 'records');
      recordsBudget.acceptRecord(kind, phase: 'records');
      expect(
        () => recordsBudget.acceptRecord(kind, phase: 'records'),
        throwsA(isA<ImportLimitException>()),
      );
    }

    final field = ImportBudget(limits: _limits());
    field.checkField('ab', phase: 'field');
    field.checkField('abc', phase: 'field');
    expect(
      () => field.checkField('abcd', phase: 'field'),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.fieldBytes,
        ),
      ),
    );

    final persisted = ImportBudget(limits: _limits());
    persisted.acceptPersistedRows(2, phase: 'persist');
    persisted.acceptPersistedRows(1, phase: 'persist');
    expect(
      () => persisted.acceptPersistedRows(1, phase: 'persist'),
      throwsA(isA<ImportLimitException>()),
    );

    final depth = ImportBudget(limits: _limits());
    depth.checkXmlDepth(2, phase: 'xml');
    depth.checkXmlDepth(3, phase: 'xml');
    expect(
      () => depth.checkXmlDepth(4, phase: 'xml'),
      throwsA(isA<ImportLimitException>()),
    );
  });

  test('duration and cancellation stop all registered work', () async {
    final expired = ImportBudget(
      limits: _limits(duration: const Duration(milliseconds: 1)),
      startedAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    expect(
      () => expired.checkpoint('duration'),
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.duration,
        ),
      ),
    );

    final cancellation = ImportCancellation();
    var callbacks = 0;
    cancellation.register(() => callbacks++);
    cancellation.register(() => callbacks++);
    cancellation.cancel();
    await cancellation.whenCancelled.timeout(const Duration(seconds: 1));
    cancellation.cancel();

    expect(callbacks, 2);
    expect(cancellation.isCancelled, isTrue);
    expect(
      cancellation.throwIfCancelled,
      throwsA(
        isA<ImportLimitException>().having(
          (error) => error.code,
          'code',
          ImportLimitCode.cancelled,
        ),
      ),
    );
  });

  test('limit errors contain only stable safe metadata', () {
    const error = ImportLimitException(
      code: ImportLimitCode.decodedBytes,
      phase: 'xmltv_expand',
      actual: 4,
      limit: 3,
    );
    final text = error.toString();

    expect(text, contains('IMPORT_DECODED_BYTES_LIMIT'));
    expect(text, contains('xmltv_expand'));
    expect(text, isNot(contains('http')));
    expect(text, isNot(contains(r'C:\')));
  });
}
