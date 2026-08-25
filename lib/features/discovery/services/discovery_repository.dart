import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_cache_store.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_data_source.dart';

class DiscoveryRepository {
  DiscoveryRepository(this._cache, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const tmdbRefreshAge = Duration(minutes: 30);
  static const seerrRefreshAge = Duration(minutes: 2);
  static const maximumOfflineAge = Duration(days: 7);

  final DiscoveryCacheStore _cache;
  final DateTime Function() _clock;

  Future<DiscoveryHomeFeed> loadHome({
    required DiscoverySource source,
    required DiscoveryDataSource dataSource,
    required DiscoveryLocale locale,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${source.name}_${locale.cacheKey}';
    final cached = await _cache.read(cacheKey);
    final now = _clock().toUtc();
    final refreshAge = source == DiscoverySource.tmdb
        ? tmdbRefreshAge
        : seerrRefreshAge;
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt.toUtc()) <= refreshAge) {
      return cached.copyWith(isStale: false);
    }

    try {
      final fresh = await dataSource.fetchHome(locale);
      await _cache.write(cacheKey, fresh);
      return fresh.copyWith(isStale: false);
    } catch (error) {
      if (_allowsOfflineFallback(error) &&
          cached != null &&
          now.difference(cached.fetchedAt.toUtc()) <= maximumOfflineAge) {
        return cached.copyWith(isStale: true);
      }
      rethrow;
    }
  }

  Future<DiscoveryPage> search({
    required DiscoveryDataSource dataSource,
    required DiscoveryLocale locale,
    required String query,
    int page = 1,
  }) => dataSource.search(query, locale: locale, page: page);

  Future<DiscoveryPage> fetchCategory({
    required DiscoveryDataSource dataSource,
    required DiscoveryLocale locale,
    required DiscoveryShelfKind kind,
    int page = 1,
  }) => dataSource.fetchCategory(kind, locale: locale, page: page);

  Future<DiscoveryMediaItem> fetchDetails({
    required DiscoveryDataSource dataSource,
    required DiscoveryLocale locale,
    required DiscoveryMediaItem item,
  }) => dataSource.fetchDetails(item, locale: locale);

  Future<DiscoveryMediaItem> requestMedia({
    required RequestCapableDiscoveryDataSource dataSource,
    required DiscoveryLocale locale,
    required DiscoveryMediaItem item,
    List<int>? seasons,
  }) => dataSource.requestMedia(item, locale: locale, seasons: seasons);

  bool _allowsOfflineFallback(Object error) =>
      error is DiscoveryApiException &&
      (error.kind == DiscoveryFailureKind.network ||
          error.kind == DiscoveryFailureKind.timeout);
}
