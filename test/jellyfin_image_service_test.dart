import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';

import 'jellyfin_test_helpers.dart';

void main() {
  const images = JellyfinImageService();

  group('JellyfinImageService', () {
    test('builds primary poster URLs with tag, maxWidth and api_key', () {
      final url = images.posterUrl(
        jellyfinTestConnection,
        itemId: 'item-1',
        imageTag: 'tag-abc',
      );

      expect(url, isNotNull);
      expect(
        url,
        'http://server:8096/Items/item-1/Images/Primary'
        '?maxWidth=400&tag=tag-abc&api_key=token-abc-123',
      );
    });

    test('builds backdrop URLs with larger default width', () {
      final url = images.backdropUrl(
        jellyfinTestConnection,
        itemId: 'item-1',
        imageTag: 'tag-backdrop',
      );

      expect(
        url,
        'http://server:8096/Items/item-1/Images/Backdrop'
        '/0?maxWidth=1600&tag=tag-backdrop&api_key=token-abc-123',
      );
    });

    test('builds a logo URL without an image index', () {
      final url = images.logoUrl(
        jellyfinTestConnection,
        itemId: 'item-1',
        imageTag: 'tag-logo',
      );

      expect(
        url,
        'http://server:8096/Items/item-1/Images/Logo'
        '?maxWidth=500&tag=tag-logo&api_key=token-abc-123',
      );
    });

    test('returns null when no image tag exists', () {
      expect(
        images.posterUrl(
          jellyfinTestConnection,
          itemId: 'item-1',
          imageTag: null,
        ),
        isNull,
      );
      expect(
        images.backdropUrl(
          jellyfinTestConnection,
          itemId: 'item-1',
          imageTag: '',
        ),
        isNull,
      );
    });
  });
}
