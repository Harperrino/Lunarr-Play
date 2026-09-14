Uri discoveryUriWithQuery(Uri base, Map<String, String>? parameters) {
  if (parameters == null || parameters.isEmpty) return base;

  final query = parameters.entries
      .map(
        (entry) =>
            '${Uri.encodeComponent(entry.key)}='
            '${Uri.encodeComponent(entry.value)}',
      )
      .join('&');
  return base.replace(query: query);
}
