import 'package:m3uxtream_player/core/diagnostics/diagnostic_sanitizer.dart';

/// Redacts credentials from IPTV / Xtream URLs and log text.
String redactStreamText(String input) {
  return DiagnosticSanitizer.sanitizeText(input).value;
}

/// Redacts credentials from a single stream URL while preserving host and stream id.
String redactStreamUrl(String input) {
  return DiagnosticSanitizer.sanitizeUrl(input).value;
}
