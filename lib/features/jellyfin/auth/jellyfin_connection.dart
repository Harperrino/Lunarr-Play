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

  /// Stable identifier for selecting and removing one saved account.
  String get credentialId => '$serverId:$userId';

  Map<String, Object> toJson() => {
    'baseUrl': baseUrl,
    'serverId': serverId,
    'serverVersion': serverVersion,
    'userId': userId,
    'username': username,
    'accessToken': accessToken,
    'deviceId': deviceId,
  };

  static JellyfinConnection? fromJson(Object? value) {
    if (value is! Map) return null;
    String? text(String key) => value[key]?.toString().trim();
    final baseUrl = text('baseUrl');
    final serverId = text('serverId');
    final serverVersion = text('serverVersion');
    final userId = text('userId');
    final username = text('username');
    final accessToken = text('accessToken');
    final deviceId = text('deviceId');
    if ([
      baseUrl,
      serverId,
      serverVersion,
      userId,
      username,
      accessToken,
      deviceId,
    ].any((entry) => entry == null || entry.isEmpty)) {
      return null;
    }
    return JellyfinConnection(
      baseUrl: baseUrl!,
      serverId: serverId!,
      serverVersion: serverVersion!,
      userId: userId!,
      username: username!,
      accessToken: accessToken!,
      deviceId: deviceId!,
    );
  }
}
