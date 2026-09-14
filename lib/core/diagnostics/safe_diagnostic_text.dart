/// Text that has crossed the central diagnostic sanitization boundary.
class SafeDiagnosticText {
  const SafeDiagnosticText.trusted(this.value);

  final String value;

  @override
  String toString() => value;
}
