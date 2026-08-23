import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';

/// Normalizes user-entered server addresses and builds Jellyfin endpoints.
class JellyfinUrlBuilder {
  const JellyfinUrlBuilder();

  static final RegExp _trailingSlashes = RegExp(r'/+$');

  /// Normalizes a user-entered server address.
  ///
  /// Accepts `http` and `https`, prepends `http://` when no scheme is given,
  /// strips trailing slashes and rejects malformed or credentialed input.
  String normalizeBaseUrl(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Server address is empty.',
      );
    }

    if (!value.contains('://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme.isEmpty ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        value.contains(RegExp(r'\s'))) {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Server address could not be parsed.',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Only http and https server addresses are supported.',
      );
    }

    final builder = Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    );
    final normalized = builder.toString().replaceAll(_trailingSlashes, '');
    if (normalized.isEmpty || normalized == '$scheme:') {
      throw const JellyfinApiException(
        kind: JellyfinFailureKind.invalidUrl,
        message: 'Server address could not be parsed.',
      );
    }
    return normalized;
  }

  Uri systemInfoPublic(String baseUrl) =>
      Uri.parse('$baseUrl/System/Info/Public');

  Uri authenticateByName(String baseUrl) =>
      Uri.parse('$baseUrl/Users/AuthenticateByName');

  Uri sessionsLogout(String baseUrl) => Uri.parse('$baseUrl/Sessions/Logout');

  Uri sessionsPlaying(String baseUrl) => Uri.parse('$baseUrl/Sessions/Playing');

  Uri sessionsPlayingProgress(String baseUrl) =>
      Uri.parse('$baseUrl/Sessions/Playing/Progress');

  Uri sessionsPlayingStopped(String baseUrl) =>
      Uri.parse('$baseUrl/Sessions/Playing/Stopped');

  Uri userViews(String baseUrl, String userId) =>
      Uri.parse('$baseUrl/Users/$userId/Views');

  Uri resumeItems(String baseUrl, String userId, {int limit = 24}) {
    return Uri.parse(
      '$baseUrl/Users/$userId/Items/Resume'
      '?Recursive=true&Limit=$limit&MediaTypes=Video',
    );
  }

  Uri nextUp(String baseUrl, String userId, {int limit = 12}) {
    return Uri.parse('$baseUrl/Shows/NextUp?UserId=$userId&Limit=$limit');
  }

  Uri latestItems(String baseUrl, String userId, {int limit = 16}) {
    return Uri.parse('$baseUrl/Users/$userId/Items/Latest?Limit=$limit');
  }

  Uri libraryItems(
    String baseUrl,
    String userId, {
    required String parentId,
    List<String> itemTypes = const [],
  }) {
    final typeFilter = itemTypes.isEmpty
        ? ''
        : '&IncludeItemTypes=${itemTypes.join(',')}';
    return Uri.parse(
      '$baseUrl/Users/$userId/Items'
      '?ParentId=$parentId&Recursive=true$typeFilter'
      '&SortBy=SortName&SortOrder=Ascending',
    );
  }

  Uri itemDetail(String baseUrl, String userId, String itemId) {
    return Uri.parse('$baseUrl/Users/$userId/Items/$itemId');
  }

  Uri seriesEpisodes(String baseUrl, String userId, String seriesId) {
    return Uri.parse(
      '$baseUrl/Shows/$seriesId/Episodes'
      '?UserId=$userId&SortBy=SortName&SortOrder=Ascending',
    );
  }

  Uri playbackInfo(String baseUrl, String itemId) =>
      Uri.parse('$baseUrl/Items/$itemId/PlaybackInfo');

  Uri mediaSegments(String baseUrl, String itemId) =>
      Uri.parse('$baseUrl/MediaSegments/$itemId');

  Uri trickplayItem(String baseUrl, String userId, String itemId) =>
      _withFields(itemDetail(baseUrl, userId, itemId), fields: 'Trickplay');

  Uri trickplayTile(
    String baseUrl,
    String itemId, {
    required int width,
    required int index,
    required String mediaSourceId,
  }) =>
      Uri.parse('$baseUrl/Videos/$itemId/Trickplay/$width/$index.jpg')
          .replace(queryParameters: {'MediaSourceId': mediaSourceId});

  Uri favoriteItem(String baseUrl, String userId, String itemId) =>
      Uri.parse('$baseUrl/Users/$userId/FavoriteItems/$itemId');

  Uri playedItem(String baseUrl, String userId, String itemId) =>
      Uri.parse('$baseUrl/Users/$userId/PlayedItems/$itemId');

  static const itemFields = 'Overview,ProductionYear,RuntimeTicks';
  static const detailItemFields =
      'Overview,ProductionYear,RuntimeTicks,Genres,People,ProviderIds,Studios,Taglines,RemoteTrailers';

  Uri _withFields(Uri uri, {String fields = itemFields, String? extraQuery}) {
    final separator = uri.hasQuery ? '&' : '?';
    final suffix = extraQuery == null ? '' : '&$extraQuery';
    return Uri.parse('$uri${separator}Fields=$fields$suffix');
  }

  Uri userViewsWithFields(String baseUrl, String userId) =>
      _withFields(userViews(baseUrl, userId));

  Uri resumeItemsWithFields(String baseUrl, String userId, {int limit = 24}) =>
      _withFields(resumeItems(baseUrl, userId, limit: limit));

  Uri nextUpWithFields(String baseUrl, String userId, {int limit = 12}) =>
      _withFields(nextUp(baseUrl, userId, limit: limit));

  Uri latestItemsWithFields(String baseUrl, String userId, {int limit = 16}) =>
      _withFields(latestItems(baseUrl, userId, limit: limit));

  Uri libraryItemsWithFields(
    String baseUrl,
    String userId, {
    required String parentId,
    List<String> itemTypes = const [],
  }) => _withFields(
    libraryItems(baseUrl, userId, parentId: parentId, itemTypes: itemTypes),
  );

  Uri itemDetailWithFields(String baseUrl, String userId, String itemId) =>
      _withFields(
        itemDetail(baseUrl, userId, itemId),
        fields: detailItemFields,
        extraQuery:
            'EnableImages=true&EnableImageTypes=Primary,Backdrop,Logo&'
            'ImageTypeLimit=1&EnableUserData=true',
      );

  Uri seriesEpisodesWithFields(
    String baseUrl,
    String userId,
    String seriesId,
  ) => _withFields(seriesEpisodes(baseUrl, userId, seriesId));
}
