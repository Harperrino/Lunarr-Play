/// Full authenticated Jellyfin session and the persisted credential context.
class JellyfinConnection {
  const JellyfinConnection({
    required this.baseUrl,
    required this.serverId,
    required this.serverVersion,
    required this.userId,
    required this.username,
    required this.accessToken,
    required this.deviceId,
  });

  /// Normalized server base URL (no trailing slash).
  final String baseUrl;

  final String serverId;
  final String serverVersion;
  final String userId;
  final String username;

  /// Session access token. Never persisted in plaintext and never logged.
  final String accessToken;

  /// Device identity sent to the server; stable for the current app run.
  final String deviceId;
}
