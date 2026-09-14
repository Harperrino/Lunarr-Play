import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/services/channel_sorting.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';

export 'package:m3uxtream_player/core/models/channel_sort_mode.dart';

final channelSortModeProvider = StateNotifierProvider.autoDispose
    .family<ChannelSortModeNotifier, ChannelSortMode, int>((ref, playlistId) {
      return ChannelSortModeNotifier(
        playlistId,
        ref.read(appStateRepositoryProvider),
      );
    });

/// Sort mode for the synthetic All-active catalog. It has its own AppState
/// key so changing it never changes a concrete playlist's ordering.
final allActiveChannelSortModeProvider =
    StateNotifierProvider.autoDispose<
      AllActiveChannelSortModeNotifier,
      ChannelSortMode
    >((ref) {
      return AllActiveChannelSortModeNotifier(
        ref.read(appStateRepositoryProvider),
      );
    });

class AllActiveChannelSortModeNotifier extends StateNotifier<ChannelSortMode> {
  AllActiveChannelSortModeNotifier(this._repository)
    : super(ChannelSortMode.providerDefault) {
    _load();
  }

  final AppStateRepository _repository;
  bool _userChanged = false;

  Future<void> _load() async {
    final persisted = await _repository.getAllActiveChannelSortMode();
    if (mounted && !_userChanged) state = persisted;
  }

  Future<void> setMode(ChannelSortMode mode) async {
    _userChanged = true;
    final previous = state;
    state = mode;
    try {
      await _repository.setAllActiveChannelSortMode(mode);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

class ChannelSortModeNotifier extends StateNotifier<ChannelSortMode> {
  ChannelSortModeNotifier(this.playlistId, this._repository)
    : super(ChannelSortMode.providerDefault) {
    _load();
  }

  /// Creates a non-persisting default notifier for isolated widget tests.
  ChannelSortModeNotifier.test(this.playlistId)
    : _repository = null,
      super(ChannelSortMode.providerDefault);

  final int playlistId;
  final AppStateRepository? _repository;
  bool _userChanged = false;

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) return;
    final persisted = await repository.getChannelSortMode(playlistId);
    if (mounted && !_userChanged) state = persisted;
  }

  Future<void> setMode(ChannelSortMode mode) async {
    _userChanged = true;
    final previous = state;
    state = mode;
    final repository = _repository;
    if (repository == null) return;
    try {
      await repository.setChannelSortMode(playlistId, mode);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

/// Sorted Live catalogue. Async so previous rows stay visible while a new
/// scope/filter/sort state computes; the generation guard ensures a stale
/// computation never overwrites a newer state.
final sortedFilteredChannelsProvider =
    AsyncNotifierProvider.autoDispose<
      SortedFilteredChannelsNotifier,
      List<Channel>
    >(SortedFilteredChannelsNotifier.new);

class SortedFilteredChannelsNotifier
    extends AutoDisposeAsyncNotifier<List<Channel>> {
  int _generation = 0;
  int _catalogGeneration = 0;
  List<Channel>? _lastCatalog;
  final Map<_ChannelSortCacheKey, List<int>> _orderedIdCache = {};

  @override
  Future<List<Channel>> build() async {
    final generation = ++_generation;
    final channels = ref.watch(filteredChannelsProvider);
    if (channels.isEmpty) return const <Channel>[];
    if (!identical(channels, _lastCatalog)) {
      _lastCatalog = channels;
      _catalogGeneration++;
    }

    final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
    final mode = scope.isAllActive
        ? ref.watch(allActiveChannelSortModeProvider)
        : scope.playlistId == null
        ? ChannelSortMode.providerDefault
        : ref.watch(channelSortModeProvider(scope.playlistId!));

    // The repository stream already delivers the final provider-default
    // order; pass it through without a second full Dart sort.
    if (mode == ChannelSortMode.providerDefault) return channels;

    final cacheKey = _ChannelSortCacheKey(
      scope: scope,
      catalogGeneration: _catalogGeneration,
      mode: mode,
    );
    final cachedIds = _orderedIdCache[cacheKey];
    final List<int> orderedIds;
    if (cachedIds != null) {
      orderedIds = cachedIds;
    } else {
      orderedIds = await compute<_ChannelSortRequest, List<int>>(
        _sortChannelIdsInIsolate,
        _ChannelSortRequest(
          channels.map(ChannelSortDto.fromChannel).toList(growable: false),
          mode,
        ),
        debugLabel: 'channel-catalog-sort',
      );
    }
    if (generation != _generation) {
      return state.valueOrNull ?? channels;
    }
    _orderedIdCache[cacheKey] = orderedIds;
    while (_orderedIdCache.length > 8) {
      _orderedIdCache.remove(_orderedIdCache.keys.first);
    }
    final byId = {for (final channel in channels) channel.id: channel};
    return [
      for (final id in orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
  }
}

class _ChannelSortRequest {
  const _ChannelSortRequest(this.channels, this.mode);

  final List<ChannelSortDto> channels;
  final ChannelSortMode mode;
}

List<int> _sortChannelIdsInIsolate(_ChannelSortRequest request) {
  return sortChannelIds(request.channels, request.mode);
}

class _ChannelSortCacheKey {
  const _ChannelSortCacheKey({
    required this.scope,
    required this.catalogGeneration,
    required this.mode,
  });

  final PlaylistCatalogScope scope;
  final int catalogGeneration;
  final ChannelSortMode mode;

  @override
  bool operator ==(Object other) =>
      other is _ChannelSortCacheKey &&
      other.scope == scope &&
      other.catalogGeneration == catalogGeneration &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(scope, catalogGeneration, mode);
}
