import 'package:drift/drift.dart';
import 'package:m3uxtream_player/core/database/database_disconnect_classifier.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';

/// Converts connection-level Drift failures into one central app-health event
/// while preserving the original exception for the feature caller.
class DatabaseHealthInterceptor extends QueryInterceptor {
  DatabaseHealthInterceptor(
    this._health, {
    this._disconnectClassifier = const DatabaseDisconnectClassifier(),
  });

  final DatabaseHealthController _health;
  final DatabaseDisconnectClassifier _disconnectClassifier;

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      if (_disconnectClassifier.isDisconnect(error)) {
        _health.reportDriftDisconnect(error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      _guard(() => executor.ensureOpen(user));

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _guard(() => executor.runBatched(statements));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runCustom(statement, args));

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runInsert(statement, args));

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runDelete(statement, args));

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runUpdate(statement, args));

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _guard(() => executor.runSelect(statement, args));
}
