/// Feature-local fail-closed redaction for every Jellyfin log message.
///
/// Scrubs access tokens, passwords, API-key query parameters and
/// authentication header values before a message reaches [AppLogger]. The
/// core sanitizer still runs as defense in depth.
class JellyfinLogRedactor {
  const JellyfinLogRedactor();

  static const String redacted = '***';

  static final RegExp _embyTokenHeaderPattern = RegExp(
    r'(X-Emby-Token:\s*)[^\s,;"]+',
    caseSensitive: false,
  );
  static final RegExp _authorizationHeaderPattern = RegExp(
    r'(X-Emby-Authorization:\s*)[^\r\n]+',
    caseSensitive: false,
  );
  static final RegExp _authorizationInnerTokenPattern = RegExp(
    r'\bToken\s*=\s*"[^"]*"',
    caseSensitive: false,
  );
  static final RegExp _credentialQueryPattern = RegExp(
    r'([?&](?:api_key|token|access_token|auth)=)[^&\s]+',
    caseSensitive: false,
  );
  static final RegExp _jsonPasswordPattern = RegExp(
    r'("(?:Pw|Password|password|Passphrase)"\s*:\s*")[^"]*(")',
  );

  /// Returns a log-safe copy of [message].
  String redact(String message) {
    var sanitized = message.replaceAllMapped(
      _embyTokenHeaderPattern,
      (match) => '${match.group(1)}$redacted',
    );
    sanitized = sanitized.replaceAllMapped(
      _authorizationHeaderPattern,
      (match) => '${match.group(1)}$redacted',
    );
    sanitized = sanitized.replaceAllMapped(
      _authorizationInnerTokenPattern,
      (match) => 'Token="$redacted"',
    );
    sanitized = sanitized.replaceAllMapped(
      _credentialQueryPattern,
      (match) => '${match.group(1)}$redacted',
    );
    sanitized = sanitized.replaceAllMapped(
      _jsonPasswordPattern,
      (match) => '${match.group(1)}$redacted${match.group(2)}',
    );
    return sanitized;
  }
}
