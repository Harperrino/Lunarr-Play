import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';

abstract interface class DiscoveryDataSource {
  Future<DiscoveryHomeFeed> fetchHome(DiscoveryLocale locale);

  Future<DiscoveryPage> fetchCategory(
    DiscoveryShelfKind kind, {
    required DiscoveryLocale locale,
    int page = 1,
  });

  Future<DiscoveryPage> search(
    String query, {
    required DiscoveryLocale locale,
    int page = 1,
  });

  Future<DiscoveryMediaItem> fetchDetails(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
  });
}

abstract interface class RequestCapableDiscoveryDataSource
    implements DiscoveryDataSource {
  Future<DiscoveryMediaItem> requestMedia(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
    List<int>? seasons,
  });
}
