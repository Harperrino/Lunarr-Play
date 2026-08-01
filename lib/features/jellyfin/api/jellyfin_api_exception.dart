/// Stable failure categories surfaced to the UI and to log lines.
///
/// The message is always sanitized and must never contain credentials,
/// passwords, access tokens or full playback URLs.
enum JellyfinFailureKind {
  invalidUrl,
  dns,
  connectionRefused,
  hostUnreachable,
  timeout,
  tls,
  notJellyfin,
  invalidCredentials,
  unknown,
}

/// Typed failure of a Jellyfin API call with a safe, redacted message.
class JellyfinApiException implements Exception {
  const JellyfinApiException({
    required this.kind,
    this.statusCode,
    this.message = '',
  });

  final JellyfinFailureKind kind;
  final int? statusCode;
  final String message;

  @override
  String toString() =>
      'JellyfinApiException(${kind.name}'
      '${statusCode == null ? '' : ', status: $statusCode'})';
}
