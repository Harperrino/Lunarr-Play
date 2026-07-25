import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/database_disconnect_classifier.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';

class ConnectionClosedException implements Exception {
  const ConnectionClosedException([this.message = 'Connection closed']);

  final String message;

  @override
  String toString() => 'ConnectionClosedException: $message';
}

class ConnectionLostException implements Exception {
  const ConnectionLostException();

  @override
  String toString() => 'ConnectionLostException: remote isolate went away';
}

void main() {
  const classifier = DatabaseDisconnectClassifier();

  group('connection-level failures are disconnects', () {
    final cases = <String, Object>{
      'isolate channel closed before response': Exception(
        'Channel was closed before receiving a response',
      ),
      'connection was closed': StateError('The connection was closed'),
      'connection is closed': Exception('database connection is closed'),
      'plain connection closed': Exception('Connection closed by peer'),
      'plain connection lost': Exception('Connection lost during transaction'),
      'database is closed': Exception('The database is closed'),
      'drift connection message': Exception(
        'Drift connection is no longer available',
      ),
      'typed ConnectionClosedException': const ConnectionClosedException(),
      'typed ConnectionLostException': const ConnectionLostException(),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(classifier.isDisconnect(entry.value), isTrue);
      });
    }
  });

  group('ordinary sqlite errors are not disconnects', () {
    final cases = <String, Object>{
      'unique constraint': Exception(
        'SqliteException(787): while executing statement, '
        'UNIQUE constraint failed: playlists.url_or_host',
      ),
      'invalid query table': Exception(
        'SqliteException(1): no such table: channels',
      ),
      'duplicate column': Exception(
        'SqliteException(1): duplicate column name: provider_order',
      ),
      'syntax error': Exception(
        'SqliteException(1): near "SELCT": syntax error',
      ),
      'foreign key constraint': Exception(
        'SqliteException(787): FOREIGN KEY constraint failed',
      ),
      'business state error': StateError('Channel no longer exists.'),
      'format error': const FormatException('Unexpected character'),
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(classifier.isDisconnect(entry.value), isFalse);
      });
    }
  });

  group('DatabaseHealthController', () {
    test('reports only the first disconnect as fatal', () {
      final controller = DatabaseHealthController();
      addTearDown(controller.dispose);

      controller.reportOperationFailure(
        Exception('Channel was closed before receiving a response'),
        StackTrace.empty,
      );
      expect(controller.state.isFatal, isTrue);
      expect(controller.state.message, isNotNull);

      controller.reportOperationFailure(
        Exception('The connection was closed'),
        StackTrace.empty,
      );
      controller.reportDriftDisconnect(
        const ConnectionClosedException(),
        StackTrace.empty,
      );
      // Still the one fatal state — identical disconnects are not re-reported.
      expect(controller.state.isFatal, isTrue);
    });

    test('ordinary sqlite errors never turn fatal', () {
      final controller = DatabaseHealthController();
      addTearDown(controller.dispose);

      controller.reportOperationFailure(
        Exception('SqliteException(787): UNIQUE constraint failed'),
        StackTrace.empty,
      );
      controller.reportOperationFailure(
        Exception('SqliteException(1): duplicate column name: provider_order'),
        StackTrace.empty,
      );
      controller.reportOperationFailure(
        StateError('Channel no longer exists.'),
        StackTrace.empty,
      );

      expect(controller.state.isFatal, isFalse);
      expect(controller.state.message, isNull);
    });
  });
}
