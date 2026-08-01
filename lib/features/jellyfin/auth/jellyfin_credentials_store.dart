import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';

/// Persistence boundary for the Jellyfin access token and its reconnect
/// context.
///
/// A persistent backend may only be enabled once a verified secure Windows
/// backend (Credential Manager / DPAPI) exists. Until then the in-memory
/// implementation is used and a login is required after every restart. No
/// plaintext fallback is allowed.
abstract interface class JellyfinCredentialsStore {
  Future<JellyfinConnection?> read();

  Future<void> write(JellyfinConnection connection);

  Future<void> clear();
}

/// Memory-only store: survives the current app run, never touches disk.
class InMemoryJellyfinCredentialsStore implements JellyfinCredentialsStore {
  JellyfinConnection? _connection;

  @override
  Future<JellyfinConnection?> read() async => _connection;

  @override
  Future<void> write(JellyfinConnection connection) async {
    _connection = connection;
  }

  @override
  Future<void> clear() async {
    _connection = null;
  }
}
