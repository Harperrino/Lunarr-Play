import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';

/// Central builder for Jellyfin image URLs.
///
/// Cards and details never construct image URLs themselves. The access token
/// travels as an `api_key` query parameter (standard Jellyfin scheme) and is
/// covered by the feature log redactor.
class JellyfinImageService {
  const JellyfinImageService();

  String? posterUrl(
    JellyfinConnection connection, {
    required String itemId,
    required String? imageTag,
    int maxWidth = 400,
  }) {
    return _imageUrl(
      connection,
      itemId: itemId,
      kind: 'Primary',
      imageTag: imageTag,
      maxWidth: maxWidth,
    );
  }

  String? backdropUrl(
    JellyfinConnection connection, {
    required String itemId,
    required String? imageTag,
    int maxWidth = 1600,
  }) {
    return _imageUrl(
      connection,
      itemId: itemId,
      kind: 'Backdrop',
      imageTag: imageTag,
      maxWidth: maxWidth,
    );
  }

  String? _imageUrl(
    JellyfinConnection connection, {
    required String itemId,
    required String kind,
    required String? imageTag,
    required int maxWidth,
  }) {
    if (imageTag == null || imageTag.isEmpty) return null;
    return '${connection.baseUrl}/Items/$itemId/Images/$kind'
        '?maxWidth=$maxWidth&tag=$imageTag'
        '&api_key=${connection.accessToken}';
  }
}
