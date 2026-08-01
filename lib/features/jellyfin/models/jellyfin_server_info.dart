/// Public system information of a Jellyfin server.
class JellyfinServerInfo {
  const JellyfinServerInfo({
    required this.baseUrl,
    required this.serverName,
    required this.serverVersion,
    required this.serverId,
    this.operatingSystem,
  });

  /// Normalized base URL (scheme, host, optional port and path, no trailing
  /// slash) that was used to reach this server.
  final String baseUrl;

  final String serverName;
  final String serverVersion;
  final String serverId;
  final String? operatingSystem;

  factory JellyfinServerInfo.fromPublicJson(
    String baseUrl,
    Map<String, dynamic> json,
  ) {
    return JellyfinServerInfo(
      baseUrl: baseUrl,
      serverName: json['ServerName'] as String? ?? '',
      serverVersion: json['Version'] as String? ?? '',
      serverId: json['Id'] as String? ?? '',
      operatingSystem: json['OperatingSystem'] as String?,
    );
  }
}
