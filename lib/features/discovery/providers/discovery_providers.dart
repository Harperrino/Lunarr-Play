import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/providers/secure_secret_store_provider.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_http_client.dart';
import 'package:m3uxtream_player/features/discovery/api/seerr_discovery_client.dart';
import 'package:m3uxtream_player/features/discovery/api/tmdb_discovery_client.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_cache_store.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_data_source.dart';
import 'package:m3uxtream_player/features/discovery/services/discovery_repository.dart';

const discoveryTmdbTokenSecretKey = 'discovery.tmdb.read_access_token';
const discoverySeerrApiKeySecretKey = 'discovery.seerr.admin_api_key';

class DiscoverySecrets {
  const DiscoverySecrets({this.tmdbToken = '', this.seerrApiKey = ''});

  final String tmdbToken;
  final String seerrApiKey;

  bool get hasTmdbToken => tmdbToken.isNotEmpty;
  bool get hasSeerrApiKey => seerrApiKey.isNotEmpty;

  DiscoverySecrets copyWith({String? tmdbToken, String? seerrApiKey}) =>
      DiscoverySecrets(
        tmdbToken: tmdbToken ?? this.tmdbToken,
        seerrApiKey: seerrApiKey ?? this.seerrApiKey,
      );
}

final discoveryPreferencesProvider =
    AsyncNotifierProvider<DiscoveryPreferencesNotifier, DiscoveryPreferences>(
      DiscoveryPreferencesNotifier.new,
    );

class DiscoveryPreferencesNotifier extends AsyncNotifier<DiscoveryPreferences> {
  @override
  Future<DiscoveryPreferences> build() =>
      ref.watch(appStateRepositoryProvider).getDiscoveryPreferences();

  Future<void> setSource(DiscoverySource source) async {
    await ref.read(appStateRepositoryProvider).setDiscoverySource(source);
    state = AsyncData(
      (state.valueOrNull ?? const DiscoveryPreferences()).copyWith(
        source: source,
      ),
    );
  }

  Future<void> setSeerrEndpoint(String endpoint) async {
    final normalized = endpoint.trim();
    await ref
        .read(appStateRepositoryProvider)
        .setDiscoverySeerrEndpoint(normalized);
    state = AsyncData(
      (state.valueOrNull ?? const DiscoveryPreferences()).copyWith(
        seerrEndpoint: normalized,
      ),
    );
  }

  Future<void> setStartupDestination(AppStartupDestination destination) async {
    await ref
        .read(appStateRepositoryProvider)
        .setStartupDestination(destination);
    state = AsyncData(
      (state.valueOrNull ?? const DiscoveryPreferences()).copyWith(
        startupDestination: destination,
      ),
    );
  }
}

final discoverySecretsProvider =
    AsyncNotifierProvider<DiscoverySecretsNotifier, DiscoverySecrets>(
      DiscoverySecretsNotifier.new,
    );

class DiscoverySecretsNotifier extends AsyncNotifier<DiscoverySecrets> {
  @override
  Future<DiscoverySecrets> build() async {
    final store = ref.watch(secureSecretStoreProvider);
    final values = await Future.wait<String?>(<Future<String?>>[
      store.read(discoveryTmdbTokenSecretKey),
      store.read(discoverySeerrApiKeySecretKey),
    ]);
    return DiscoverySecrets(
      tmdbToken: values[0] ?? '',
      seerrApiKey: values[1] ?? '',
    );
  }

  Future<void> setTmdbToken(String token) async {
    final value = token.trim();
    final store = ref.read(secureSecretStoreProvider);
    value.isEmpty
        ? await store.delete(discoveryTmdbTokenSecretKey)
        : await store.write(discoveryTmdbTokenSecretKey, value);
    state = AsyncData(
      (state.valueOrNull ?? const DiscoverySecrets()).copyWith(
        tmdbToken: value,
      ),
    );
  }

  Future<void> setSeerrApiKey(String key) async {
    final value = key.trim();
    final store = ref.read(secureSecretStoreProvider);
    value.isEmpty
        ? await store.delete(discoverySeerrApiKeySecretKey)
        : await store.write(discoverySeerrApiKeySecretKey, value);
    state = AsyncData(
      (state.valueOrNull ?? const DiscoverySecrets()).copyWith(
        seerrApiKey: value,
      ),
    );
  }
}

final discoveryRawHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final discoveryHttpClientProvider = Provider<DiscoveryHttpClient>((ref) {
  return DiscoveryHttpClient(ref.watch(discoveryRawHttpClientProvider));
});

final discoveryCacheStoreProvider = Provider<DiscoveryCacheStore>((ref) {
  return FileDiscoveryCacheStore();
});

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(ref.watch(discoveryCacheStoreProvider));
});

final discoveryLocaleProvider = Provider<DiscoveryLocale>((ref) {
  final locale = ui.PlatformDispatcher.instance.locale;
  return DiscoveryLocale(
    language: locale.languageCode.isEmpty ? 'en' : locale.languageCode,
    region: locale.countryCode?.isNotEmpty == true ? locale.countryCode! : 'US',
  );
});

DiscoveryDataSource discoveryDataSourceFor(
  Ref ref,
  DiscoveryPreferences preferences,
  DiscoverySecrets secrets,
) => switch (preferences.source) {
  DiscoverySource.tmdb => TmdbDiscoveryClient(
    httpClient: ref.read(discoveryHttpClientProvider),
    readAccessToken: secrets.tmdbToken,
  ),
  DiscoverySource.seerr => SeerrDiscoveryClient(
    httpClient: ref.read(discoveryHttpClientProvider),
    endpoint: preferences.seerrEndpoint,
    apiKey: secrets.seerrApiKey,
  ),
};

final discoveryDataSourceProvider = FutureProvider<DiscoveryDataSource>((
  ref,
) async {
  final preferences = await ref.watch(discoveryPreferencesProvider.future);
  final secrets = await ref.watch(discoverySecretsProvider.future);
  _validateConfiguration(preferences, secrets);
  return discoveryDataSourceFor(ref, preferences, secrets);
});

final discoveryHomeProvider =
    AsyncNotifierProvider.autoDispose<DiscoveryHomeNotifier, DiscoveryHomeFeed>(
      DiscoveryHomeNotifier.new,
    );

class DiscoveryHomeNotifier
    extends AutoDisposeAsyncNotifier<DiscoveryHomeFeed> {
  @override
  Future<DiscoveryHomeFeed> build() => _load();

  Future<DiscoveryHomeFeed> _load({bool forceRefresh = false}) async {
    final preferences = await ref.watch(discoveryPreferencesProvider.future);
    final dataSource = await ref.watch(discoveryDataSourceProvider.future);
    return ref
        .watch(discoveryRepositoryProvider)
        .loadHome(
          source: preferences.source,
          dataSource: dataSource,
          locale: ref.watch(discoveryLocaleProvider),
          forceRefresh: forceRefresh,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DiscoveryHomeFeed>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(forceRefresh: true));
  }
}

class DiscoverySearchState {
  const DiscoverySearchState({
    this.query = '',
    this.items = const <DiscoveryMediaItem>[],
    this.page = 0,
    this.totalPages = 0,
  });

  final String query;
  final List<DiscoveryMediaItem> items;
  final int page;
  final int totalPages;
  bool get hasMore => page > 0 && page < totalPages;
}

final discoverySearchProvider =
    AsyncNotifierProvider.autoDispose<
      DiscoverySearchNotifier,
      DiscoverySearchState
    >(DiscoverySearchNotifier.new);

class DiscoverySearchNotifier
    extends AutoDisposeAsyncNotifier<DiscoverySearchState> {
  int _generation = 0;
  Timer? _debounce;

  @override
  Future<DiscoverySearchState> build() async {
    _generation++;
    _debounce?.cancel();
    ref.onDispose(() {
      _generation++;
      _debounce?.cancel();
    });
    await ref.watch(discoveryPreferencesProvider.future);
    await ref.watch(discoverySecretsProvider.future);
    return const DiscoverySearchState();
  }

  void setQuery(String query) {
    final previous = state.valueOrNull;
    _debounce?.cancel();
    _generation++;
    if (query.trim().isEmpty) {
      state = const AsyncData(DiscoverySearchState());
      return;
    }
    state = AsyncData(
      DiscoverySearchState(
        query: query,
        items: previous?.query.trim() == query.trim()
            ? previous!.items
            : const <DiscoveryMediaItem>[],
        page: previous?.query.trim() == query.trim() ? previous!.page : 0,
        totalPages: previous?.query.trim() == query.trim()
            ? previous!.totalPages
            : 0,
      ),
    );
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(search(query));
    });
  }

  Future<void> search(String query, {bool append = false}) async {
    final normalized = query.trim();
    _debounce?.cancel();
    final generation = ++_generation;
    if (normalized.isEmpty) {
      state = const AsyncData(DiscoverySearchState());
      return;
    }
    final previous = state.valueOrNull;
    final page = append && previous?.query.trim() == normalized
        ? previous!.page + 1
        : 1;
    final pending = DiscoverySearchState(
      query: query,
      items: append && previous?.query.trim() == normalized
          ? previous!.items
          : const <DiscoveryMediaItem>[],
      page: append && previous?.query.trim() == normalized ? previous!.page : 0,
      totalPages: append && previous?.query.trim() == normalized
          ? previous!.totalPages
          : 0,
    );
    state = AsyncLoading<DiscoverySearchState>().copyWithPrevious(
      AsyncData(pending),
    );
    try {
      final source = await ref.read(discoveryDataSourceProvider.future);
      final result = await ref
          .read(discoveryRepositoryProvider)
          .search(
            dataSource: source,
            locale: ref.read(discoveryLocaleProvider),
            query: normalized,
            page: page,
          );
      if (generation != _generation) return;
      state = AsyncData(
        DiscoverySearchState(
          query: query,
          items: append && previous?.query.trim() == normalized
              ? <DiscoveryMediaItem>[...previous!.items, ...result.items]
              : result.items,
          page: result.page,
          totalPages: result.totalPages,
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      state = AsyncError<DiscoverySearchState>(
        error,
        stackTrace,
      ).copyWithPrevious(AsyncData(pending));
    }
  }

  void clear() {
    _debounce?.cancel();
    _generation++;
    state = const AsyncData(DiscoverySearchState());
  }
}

class DiscoveryCategoryState {
  const DiscoveryCategoryState({
    required this.kind,
    this.items = const <DiscoveryMediaItem>[],
    this.page = 0,
    this.totalPages = 0,
  });

  final DiscoveryShelfKind kind;
  final List<DiscoveryMediaItem> items;
  final int page;
  final int totalPages;
  bool get hasMore => page > 0 && page < totalPages;
}

final discoveryCategoryProvider = AsyncNotifierProvider.autoDispose
    .family<
      DiscoveryCategoryNotifier,
      DiscoveryCategoryState,
      DiscoveryShelfKind
    >(DiscoveryCategoryNotifier.new);

class DiscoveryCategoryNotifier
    extends
        AutoDisposeFamilyAsyncNotifier<
          DiscoveryCategoryState,
          DiscoveryShelfKind
        > {
  int _generation = 0;

  @override
  Future<DiscoveryCategoryState> build(DiscoveryShelfKind arg) async {
    _generation++;
    ref.onDispose(() => _generation++);
    return _load(arg, page: 1);
  }

  Future<DiscoveryCategoryState> _load(
    DiscoveryShelfKind kind, {
    required int page,
  }) async {
    final source = await ref.read(discoveryDataSourceProvider.future);
    final result = await ref
        .read(discoveryRepositoryProvider)
        .fetchCategory(
          dataSource: source,
          locale: ref.read(discoveryLocaleProvider),
          kind: kind,
          page: page,
        );
    return DiscoveryCategoryState(
      kind: kind,
      items: result.items,
      page: result.page,
      totalPages: result.totalPages,
    );
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = const AsyncLoading<DiscoveryCategoryState>().copyWithPrevious(
      state,
    );
    try {
      final result = await _load(arg, page: 1);
      if (generation == _generation) state = AsyncData(result);
    } catch (error, stackTrace) {
      if (generation == _generation) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final previous = state.valueOrNull;
    if (previous == null || !previous.hasMore || state.isLoading) return;
    final generation = ++_generation;
    state = const AsyncLoading<DiscoveryCategoryState>().copyWithPrevious(
      state,
    );
    try {
      final next = await _load(arg, page: previous.page + 1);
      if (generation != _generation) return;
      final unique = <String, DiscoveryMediaItem>{
        for (final item in <DiscoveryMediaItem>[
          ...previous.items,
          ...next.items,
        ])
          '${item.mediaType.name}:${item.id}': item,
      };
      state = AsyncData(
        DiscoveryCategoryState(
          kind: arg,
          items: unique.values.toList(growable: false),
          page: next.page,
          totalPages: next.totalPages,
        ),
      );
    } catch (error, stackTrace) {
      if (generation == _generation) {
        state = AsyncError<DiscoveryCategoryState>(
          error,
          stackTrace,
        ).copyWithPrevious(AsyncData(previous));
      }
    }
  }
}

const discoveryDetailsRequestDebounce = Duration(milliseconds: 120);

final discoveryDetailsProvider = FutureProvider.autoDispose
    .family<DiscoveryMediaItem, DiscoveryMediaItem>((ref, item) async {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      await Future<void>.delayed(discoveryDetailsRequestDebounce);
      if (disposed) return item;
      final source = await ref.watch(discoveryDataSourceProvider.future);
      return ref
          .watch(discoveryRepositoryProvider)
          .fetchDetails(
            dataSource: source,
            locale: ref.watch(discoveryLocaleProvider),
            item: item,
          );
    });

final discoveryRequestProvider =
    AsyncNotifierProvider<DiscoveryRequestNotifier, DiscoveryMediaItem?>(
      DiscoveryRequestNotifier.new,
    );

class DiscoveryRequestNotifier extends AsyncNotifier<DiscoveryMediaItem?> {
  int _generation = 0;

  @override
  Future<DiscoveryMediaItem?> build() async => null;

  Future<DiscoveryMediaItem?> request(
    DiscoveryMediaItem item, {
    List<int>? seasons,
  }) async {
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      final source = await ref.read(discoveryDataSourceProvider.future);
      if (source is! RequestCapableDiscoveryDataSource) {
        throw const DiscoveryApiException(
          DiscoveryFailureKind.missingConfiguration,
        );
      }
      final result = await ref
          .read(discoveryRepositoryProvider)
          .requestMedia(
            dataSource: source,
            locale: ref.read(discoveryLocaleProvider),
            item: item,
            seasons: seasons,
          );
      if (generation != _generation) return null;
      state = AsyncData(result);
      ref.invalidate(discoveryDetailsProvider(item));
      ref.invalidate(discoveryHomeProvider);
      return result;
    } catch (error, stackTrace) {
      if (generation == _generation) state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

void _validateConfiguration(
  DiscoveryPreferences preferences,
  DiscoverySecrets secrets,
) {
  final valid = switch (preferences.source) {
    DiscoverySource.tmdb => secrets.hasTmdbToken,
    DiscoverySource.seerr =>
      preferences.seerrEndpoint.isNotEmpty && secrets.hasSeerrApiKey,
  };
  if (!valid) {
    throw const DiscoveryApiException(
      DiscoveryFailureKind.missingConfiguration,
    );
  }
}
