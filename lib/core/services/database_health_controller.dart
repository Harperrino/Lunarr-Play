import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/database_disconnect_classifier.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';

/// Process-wide database health shown by the root shell.
class DatabaseHealthState {
  const DatabaseHealthState({this.isFatal = false, this.message});

  final bool isFatal;
  final String? message;
}

class DatabaseHealthController extends StateNotifier<DatabaseHealthState> {
  DatabaseHealthController({
    this._disconnectClassifier = const DatabaseDisconnectClassifier(),
  }) : super(const DatabaseHealthState());

  final DatabaseDisconnectClassifier _disconnectClassifier;

  /// Records only the first connection-level Drift failure. Ordinary SQL or
  /// validation errors remain local to their feature and do not blank the UI.
  void reportDriftDisconnect(Object error, StackTrace stackTrace) {
    if (state.isFatal) return;

    const message =
        'Datenbankverbindung unterbrochen. Bitte die Anwendung neu starten.';
    state = const DatabaseHealthState(isFatal: true, message: message);
    AppLogger.error(
      'DatabaseHealth: Drift disconnect detected (first occurrence); restart required.',
      error,
      stackTrace,
    );
  }

  void reportOperationFailure(Object error, StackTrace stackTrace) {
    if (_disconnectClassifier.isDisconnect(error)) {
      reportDriftDisconnect(error, stackTrace);
    }
  }
}

final databaseHealthProvider =
    StateNotifierProvider<DatabaseHealthController, DatabaseHealthState>(
      (ref) => DatabaseHealthController(),
    );
