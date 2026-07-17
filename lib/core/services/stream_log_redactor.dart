const _sensitiveQueryKeys = {
  'auth',
  'key',
  'pass',
  'password',
  'session',
  'token',
  'user',
  'username',
};

/// Redacts credentials from IPTV / Xtream URLs and log text.
String redactStreamText(String input) {
  final urlPattern = RegExp("https?:\\/\\/[^\\s'\\\"]+");
  return input.replaceAllMapped(
    urlPattern,
    (match) => redactStreamUrl(match.group(0)!),
  );
}

/// Redacts credentials from a single stream URL while preserving host and stream id.
String redactStreamUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;

  Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return input;
  }

  final queryParameters = <String, String>{};
  uri.queryParametersAll.forEach((key, values) {
    final lowerKey = key.toLowerCase();
    if (_sensitiveQueryKeys.contains(lowerKey)) {
      queryParameters[key] = '***';
    } else {
      queryParameters[key] = values.join(',');
    }
  });

  final pathSegments = List<String>.from(uri.pathSegments);
  if (pathSegments.isNotEmpty) {
    final scope = pathSegments.first.toLowerCase();
    if ((scope == 'live' || scope == 'movie' || scope == 'series') &&
        pathSegments.length >= 4) {
      pathSegments[1] = '***';
      pathSegments[2] = '***';
    }
  }

  return uri
      .replace(
        userInfo: uri.userInfo.isNotEmpty ? '***:***' : '',
        pathSegments: pathSegments,
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      )
      .toString();
}
