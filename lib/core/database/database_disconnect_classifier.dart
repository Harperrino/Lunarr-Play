/// Central, testable boundary that decides whether a database error means
/// the underlying Drift/SQLite connection is gone.
///
/// Only connection-level failures qualify: closed channels between isolates,
/// dropped remote connections and use-after-close. Ordinary SQLite errors
/// (constraint violations, invalid queries, duplicate columns) stay local to
/// their feature and must never be reported as a fatal disconnect.
class DatabaseDisconnectClassifier {
  const DatabaseDisconnectClassifier();

  /// Exception type names (lowercased) that always mean a lost connection.
  /// Drift background-isolate channels surface as `ConnectionClosedException`
  /// or `ConnectionLostException` from the isolate transport.
  static const _disconnectTypeMarkers = <String>[
    'connectionclosed',
    'connectionlost',
  ];

  /// Message fragments (lowercased) emitted when the connection is gone.
  static const _disconnectMessageMarkers = <String>[
    'channel was closed before receiving a response',
    'connection was closed',
    'connection is closed',
    'connection closed',
    'connection lost',
    'database is closed',
    'database connection is closed',
    'drift connection',
  ];

  bool isDisconnect(Object error) {
    final type = error.runtimeType.toString().toLowerCase();
    for (final marker in _disconnectTypeMarkers) {
      if (type.contains(marker)) return true;
    }
    final message = error.toString().toLowerCase();
    for (final marker in _disconnectMessageMarkers) {
      if (message.contains(marker)) return true;
    }
    return false;
  }
}
