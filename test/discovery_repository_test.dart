import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_cache_store.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_data_source.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_repository.dart';

class _Source implements DiscoveryDataSource {
  _Source({required this.home});

  Object home;
  int homeCalls = 0;

  @override
  Future<DiscoveryHomeFeed> fetchHome(DiscoveryLocale locale) async {
    homeCalls++;
    if (home case final DiscoveryHomeFeed feed) return feed;
    throw home;
  }

  @override
  Future<DiscoveryPage> fetchCategory(
    DiscoveryShelfKind kind, {
    required DiscoveryLocale locale,
    int page = 1,
  }) async => DiscoveryPage(items: const [], page: page, totalPages: page);

  @override
  Future<DiscoveryMediaItem> fetchDetails(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
  }) async => item;

  @override
  Future<DiscoveryPage> search(
    String query, {
    required DiscoveryLocale locale,
    int page = 1,
  }) async => DiscoveryPage(items: const [], page: page, totalPages: page);
}

DiscoveryHomeFeed _feed(DateTime fetchedAt, {DiscoverySource? source}) =>
    DiscoveryHomeFeed(
      source: source ?? DiscoverySource.tmdb,
      heroItems: const <DiscoveryMediaItem>[
        DiscoveryMediaItem(
          id: 1,
          mediaType: DiscoveryMediaType.movie,
          title: 'Cached movie',
          adult: true,
        ),
      ],
      shelves: const <DiscoveryShelf>[],
      fetchedAt: fetchedAt,
    );

void main() {
  const locale = DiscoveryLocale(language: 'en', region: 'US');

  test('TMDB cache is fresh for 30 minutes', () async {
    final now = DateTime.utc(2026, 8, 23, 12);
    final cache = InMemoryDiscoveryCacheStore();
    await cache.write(
      'tmdb_en_US',
      _feed(now.subtract(const Duration(minutes: 29))),
    );
    final source = _Source(home: _feed(now));
    final repository = DiscoveryRepository(cache, clock: () => now);

    final result = await repository.loadHome(
      source: DiscoverySource.tmdb,
      dataSource: source,
      locale: locale,
    );

    expect(source.homeCalls, 0);
    expect(result.isStale, isFalse);
    expect(result.heroItems.single.adult, isTrue);
  });

  test('Seerr cache refreshes after two minutes', () async {
    final now = DateTime.utc(2026, 8, 23, 12);
    final cache = InMemoryDiscoveryCacheStore();
    await cache.write(
      'seerr_en_US',
      _feed(
        now.subtract(const Duration(minutes: 3)),
        source: DiscoverySource.seerr,
      ),
    );
    final fresh = _feed(now, source: DiscoverySource.seerr);
    final source = _Source(home: fresh);
    final repository = DiscoveryRepository(cache, clock: () => now);

    final result = await repository.loadHome(
      source: DiscoverySource.seerr,
      dataSource: source,
      locale: locale,
    );

    expect(source.homeCalls, 1);
    expect(result.fetchedAt, now);
  });

  test('network failures expose a seven-day last-known-good copy', () async {
    final now = DateTime.utc(2026, 8, 23, 12);
    final cache = InMemoryDiscoveryCacheStore();
    await cache.write(
      'tmdb_en_US',
      _feed(now.subtract(const Duration(days: 6))),
    );
    final source = _Source(
      home: const DiscoveryApiException(DiscoveryFailureKind.network),
    );
    final repository = DiscoveryRepository(cache, clock: () => now);

    final result = await repository.loadHome(
      source: DiscoverySource.tmdb,
      dataSource: source,
      locale: locale,
    );

    expect(result.isStale, isTrue);
  });

  test('authentication failures never hide behind stale cache', () async {
    final now = DateTime.utc(2026, 8, 23, 12);
    final cache = InMemoryDiscoveryCacheStore();
    await cache.write(
      'tmdb_en_US',
      _feed(now.subtract(const Duration(hours: 1))),
    );
    final source = _Source(
      home: const DiscoveryApiException(DiscoveryFailureKind.unauthorized),
    );
    final repository = DiscoveryRepository(cache, clock: () => now);

    await expectLater(
      repository.loadHome(
        source: DiscoverySource.tmdb,
        dataSource: source,
        locale: locale,
        forceRefresh: true,
      ),
      throwsA(
        isA<DiscoveryApiException>().having(
          (error) => error.kind,
          'kind',
          DiscoveryFailureKind.unauthorized,
        ),
      ),
    );
  });

  test('offline cache older than seven days is rejected', () async {
    final now = DateTime.utc(2026, 8, 23, 12);
    final cache = InMemoryDiscoveryCacheStore();
    await cache.write(
      'tmdb_en_US',
      _feed(now.subtract(const Duration(days: 8))),
    );
    final repository = DiscoveryRepository(cache, clock: () => now);

    await expectLater(
      repository.loadHome(
        source: DiscoverySource.tmdb,
        dataSource: _Source(
          home: const DiscoveryApiException(DiscoveryFailureKind.timeout),
        ),
        locale: locale,
      ),
      throwsA(isA<DiscoveryApiException>()),
    );
  });
}
