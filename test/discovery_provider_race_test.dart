import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_cache_store.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_data_source.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_repository.dart';

class _Preferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async => const DiscoveryPreferences();
}

class _Secrets extends DiscoverySecretsNotifier {
  @override
  Future<DiscoverySecrets> build() async =>
      const DiscoverySecrets(tmdbToken: 'fixture-token');
}

class _RaceSource implements DiscoveryDataSource {
  final Map<String, Completer<DiscoveryPage>> searches = {};
  final List<int> detailRequests = <int>[];

  @override
  Future<DiscoveryPage> search(
    String query, {
    required DiscoveryLocale locale,
    int page = 1,
  }) {
    final completer = Completer<DiscoveryPage>();
    searches[query] = completer;
    return completer.future;
  }

  @override
  Future<DiscoveryPage> fetchCategory(
    DiscoveryShelfKind kind, {
    required DiscoveryLocale locale,
    int page = 1,
  }) async => DiscoveryPage(items: const [], page: page, totalPages: page);

  @override
  Future<DiscoveryHomeFeed> fetchHome(DiscoveryLocale locale) async =>
      DiscoveryHomeFeed(
        source: DiscoverySource.tmdb,
        heroItems: const [],
        shelves: const [],
        fetchedAt: DateTime.utc(2026),
      );

  @override
  Future<DiscoveryMediaItem> fetchDetails(
    DiscoveryMediaItem item, {
    required DiscoveryLocale locale,
  }) async {
    detailRequests.add(item.id);
    return item;
  }
}

void main() {
  test('late search responses cannot replace a newer query', () async {
    final source = _RaceSource();
    final container = ProviderContainer(
      overrides: [
        discoveryPreferencesProvider.overrideWith(_Preferences.new),
        discoverySecretsProvider.overrideWith(_Secrets.new),
        discoveryDataSourceProvider.overrideWith((ref) async => source),
        discoveryRepositoryProvider.overrideWithValue(
          DiscoveryRepository(InMemoryDiscoveryCacheStore()),
        ),
        discoveryLocaleProvider.overrideWithValue(
          const DiscoveryLocale(language: 'en', region: 'US'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      discoverySearchProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(discoverySearchProvider.future);
    final notifier = container.read(discoverySearchProvider.notifier);

    final oldRequest = notifier.search('old');
    await Future<void>.delayed(Duration.zero);
    final newRequest = notifier.search('new');
    await Future<void>.delayed(Duration.zero);
    source.searches['new']!.complete(
      const DiscoveryPage(
        items: <DiscoveryMediaItem>[
          DiscoveryMediaItem(
            id: 2,
            mediaType: DiscoveryMediaType.movie,
            title: 'New result',
          ),
        ],
        page: 1,
        totalPages: 1,
      ),
    );
    await newRequest;
    source.searches['old']!.complete(
      const DiscoveryPage(
        items: <DiscoveryMediaItem>[
          DiscoveryMediaItem(
            id: 1,
            mediaType: DiscoveryMediaType.movie,
            title: 'Old result',
          ),
        ],
        page: 1,
        totalPages: 1,
      ),
    );
    await oldRequest;

    final state = container.read(discoverySearchProvider).requireValue;
    expect(state.query, 'new');
    expect(state.items.single.title, 'New result');
  });

  test('invalidating a session rejects its late search response', () async {
    final source = _RaceSource();
    final container = ProviderContainer(
      overrides: [
        discoveryPreferencesProvider.overrideWith(_Preferences.new),
        discoverySecretsProvider.overrideWith(_Secrets.new),
        discoveryDataSourceProvider.overrideWith((ref) async => source),
        discoveryRepositoryProvider.overrideWithValue(
          DiscoveryRepository(InMemoryDiscoveryCacheStore()),
        ),
        discoveryLocaleProvider.overrideWithValue(
          const DiscoveryLocale(language: 'en', region: 'US'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(discoverySearchProvider.future);
    final request = container
        .read(discoverySearchProvider.notifier)
        .search('abandoned');
    await Future<void>.delayed(Duration.zero);
    container.invalidate(discoverySearchProvider);
    source.searches['abandoned']!.complete(
      const DiscoveryPage(
        items: <DiscoveryMediaItem>[
          DiscoveryMediaItem(
            id: 9,
            mediaType: DiscoveryMediaType.movie,
            title: 'Late result',
          ),
        ],
        page: 1,
        totalPages: 1,
      ),
    );
    await request;

    final reset = await container.read(discoverySearchProvider.future);
    expect(reset.query, isEmpty);
    expect(reset.items, isEmpty);
  });

  test('rapid detail replacement skips the superseded request', () async {
    final source = _RaceSource();
    final container = ProviderContainer(
      overrides: [
        discoveryPreferencesProvider.overrideWith(_Preferences.new),
        discoverySecretsProvider.overrideWith(_Secrets.new),
        discoveryDataSourceProvider.overrideWith((ref) async => source),
        discoveryRepositoryProvider.overrideWithValue(
          DiscoveryRepository(InMemoryDiscoveryCacheStore()),
        ),
        discoveryLocaleProvider.overrideWithValue(
          const DiscoveryLocale(language: 'en', region: 'US'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(discoveryDataSourceProvider.future);
    const first = DiscoveryMediaItem(
      id: 1,
      mediaType: DiscoveryMediaType.movie,
      title: 'First',
    );
    const second = DiscoveryMediaItem(
      id: 2,
      mediaType: DiscoveryMediaType.movie,
      title: 'Second',
    );

    final firstSubscription = container.listen(
      discoveryDetailsProvider(first),
      (_, _) {},
      fireImmediately: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    firstSubscription.close();
    final secondSubscription = container.listen(
      discoveryDetailsProvider(second),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(secondSubscription.close);
    await container.read(discoveryDetailsProvider(second).future);

    expect(source.detailRequests, <int>[2]);
  });
}
