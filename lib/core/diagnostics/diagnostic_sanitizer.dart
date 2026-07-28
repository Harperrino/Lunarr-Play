import 'package:m3uxtream_player/core/diagnostics/safe_diagnostic_error.dart';
import 'package:m3uxtream_player/core/diagnostics/safe_diagnostic_text.dart';

/// Fail-closed sanitization for every diagnostic output channel.
class DiagnosticSanitizer {
  DiagnosticSanitizer._();

  static const redactedUrl = '[REDACTED_URL]';
  static const redactedPath = '[LOCAL_PATH]';

  static final RegExp _urlPattern = RegExp(
    r'''https?://[^\s<>"']+''',
    caseSensitive: false,
  );
  static final RegExp _drivePathPattern = RegExp(
    r'''(?<![A-Za-z])[A-Za-z]:[\\/][^\r\n"'<>|)]+?(?=\s+(?:and|with|from|at)\s|$|[,;"'<>|)])''',
    caseSensitive: false,
  );
  static final RegExp _invalidPercentEscapePattern = RegExp(
    r'''%(?![0-9A-Fa-f]{2})''',
  );
  static final RegExp _uncPathPattern = RegExp(
    r'''\\\\[^\r\n"'<>|)]+?(?=\s+(?:and|with|from|at)\s|$|[,;"'<>|)])''',
    caseSensitive: false,
  );
  static final RegExp _unixPrivatePathPattern = RegExp(
    r'''/(?:Users|home|private|var/folders|tmp)/[^\r\n"'<>|)]+?(?=\s+(?:and|with|from|at)\s|$|[,;"'<>|)])''',
    caseSensitive: false,
  );
  static final RegExp _credentialAssignmentPattern = RegExp(
    r'''(?:access[-_]?token|refresh[-_]?token|api[-_]?key|authorization|credential|password|passwd|secret|session|token|username|user|pass|pwd)\s*[:=]\s*[^\s,;&]+''',
    caseSensitive: false,
  );
  static final RegExp _sensitiveFragmentPattern = RegExp(
    r'''(?:access[-_]?token|refresh[-_]?token|api[-_]?key|authorization|credential|password|passwd|secret|session|token|username|user|pass|pwd)\s*=''',
    caseSensitive: false,
  );

  static const Set<String> _sensitiveQueryKeys = {
    'accesstoken',
    'apikey',
    'auth',
    'authorization',
    'credential',
    'key',
    'pass',
    'passwd',
    'password',
    'pwd',
    'refreshtoken',
    'secret',
    'session',
    'signature',
    'token',
    'user',
    'username',
  };

  static SafeDiagnosticText sanitizeText(String input) {
    var sanitized = input.replaceAllMapped(
      _urlPattern,
      (match) => sanitizeUrl(match.group(0)!).value,
    );
    sanitized = sanitized.replaceAll(_uncPathPattern, redactedPath);
    sanitized = sanitized.replaceAll(_drivePathPattern, redactedPath);
    sanitized = sanitized.replaceAll(_unixPrivatePathPattern, redactedPath);
    sanitized = sanitized.replaceAllMapped(_credentialAssignmentPattern, (
      match,
    ) {
      final assignment = match.group(0)!;
      final separator = assignment.contains(':') ? ':' : '=';
      final key = assignment.split(RegExp(r'[:=]')).first.trim();
      return '$key$separator***';
    });
    return SafeDiagnosticText.trusted(sanitized);
  }

  static SafeDiagnosticText sanitizeUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const SafeDiagnosticText.trusted('');
    if (_invalidPercentEscapePattern.hasMatch(trimmed)) {
      return const SafeDiagnosticText.trusted(redactedUrl);
    }

    try {
      final uri = Uri.parse(trimmed);
      final scheme = uri.scheme.toLowerCase();
      if ((scheme != 'http' && scheme != 'https') || uri.host.isEmpty) {
        return const SafeDiagnosticText.trusted(redactedUrl);
      }

      final queryParameters = <String, String>{};
      for (final entry in uri.queryParametersAll.entries) {
        final normalizedKey = _normalizeKey(entry.key);
        if (_sensitiveQueryKeys.contains(normalizedKey)) {
          queryParameters[entry.key] = '***';
        } else {
          queryParameters[entry.key] = entry.value
              .map((value) => sanitizeText(value).value)
              .join(',');
        }
      }

      final pathSegments = List<String>.from(uri.pathSegments);
      for (var index = 0; index < pathSegments.length; index++) {
        final scope = pathSegments[index].toLowerCase();
        if ((scope == 'live' || scope == 'movie' || scope == 'series') &&
            index + 3 < pathSegments.length) {
          pathSegments[index + 1] = '***';
          pathSegments[index + 2] = '***';
          break;
        }
      }

      final fragment =
          uri.fragment.isNotEmpty &&
              _sensitiveFragmentPattern.hasMatch(uri.fragment)
          ? '***'
          : sanitizeText(uri.fragment).value;
      return SafeDiagnosticText.trusted(
        uri
            .replace(
              userInfo: uri.userInfo.isNotEmpty ? '***:***' : '',
              pathSegments: pathSegments,
              queryParameters: queryParameters.isEmpty ? null : queryParameters,
              fragment: fragment,
            )
            .toString(),
      );
    } catch (_) {
      return const SafeDiagnosticText.trusted(redactedUrl);
    }
  }

  static SafeDiagnosticError sanitizeError(Object error) {
    final type = sanitizeText(error.runtimeType.toString()).value;
    String description;
    try {
      description = error.toString();
    } catch (_) {
      description = 'Diagnostic error text unavailable.';
    }
    return SafeDiagnosticError(
      type: type,
      description: sanitizeText(description),
    );
  }

  static StackTrace sanitizeStackTrace(StackTrace stackTrace) {
    return StackTrace.fromString(sanitizeText(stackTrace.toString()).value);
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
