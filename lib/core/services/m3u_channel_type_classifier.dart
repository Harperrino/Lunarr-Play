/// Classifies M3U entries into the app's playback domains.
abstract final class M3uChannelTypeClassifier {
  static final RegExp _seriesEpisodePattern = RegExp(
    r'(^|[^a-z0-9])(s\d{1,2}e\d{1,3}|\d{1,2}x\d{1,3})([^a-z0-9]|$)',
    caseSensitive: false,
  );

  static const _vodExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv'];

  static String classify({
    required String url,
    required String name,
    String? groupName,
  }) {
    final lowercaseUrl = url.toLowerCase();
    final lowercaseGroup = groupName?.toLowerCase() ?? '';
    final lowercaseName = name.toLowerCase();

    final hasVodExtension = _vodExtensions.any(
      (extension) =>
          lowercaseUrl.endsWith(extension) ||
          lowercaseUrl.contains('$extension?'),
    );

    if (hasVodExtension) {
      return _looksLikeSeries(lowercaseGroup, lowercaseName) ? 'series' : 'vod';
    }

    if (_containsAny(lowercaseGroup, const [
      'movie',
      'film',
      'cinema',
      'vod',
    ])) {
      return 'vod';
    }

    if (_containsAny(lowercaseGroup, const [
      'series',
      'staffel',
      'season',
      'shows',
    ])) {
      return 'series';
    }

    return 'live';
  }

  static bool _looksLikeSeries(String group, String name) {
    return _containsAny(group, const ['series', 'staffel', 'season', 'show']) ||
        _containsAny(name, const ['staffel', 'season']) ||
        _seriesEpisodePattern.hasMatch(name);
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
