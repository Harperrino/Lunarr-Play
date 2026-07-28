import 'package:m3uxtream_player/core/diagnostics/safe_diagnostic_text.dart';

/// Safe diagnostic projection of an arbitrary error object.
class SafeDiagnosticError {
  const SafeDiagnosticError({required this.type, required this.description});

  final String type;
  final SafeDiagnosticText description;

  @override
  String toString() => '$type: ${description.value}';
}
