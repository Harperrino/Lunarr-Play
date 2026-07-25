import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
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

  @override
  Future<List<Channel>> build() async {
    final generation = ++_generation;
    final channels = ref.watch(filteredChannelsProvider);
    if (channels.isEmpty) return const <Channel>[];

    final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
    final mode = scope.isAllActive
        ? ref.watch(allActiveChannelSortModeProvider)
        : scope.playlistId == null
        ? ChannelSortMode.providerDefault
        : ref.watch(channelSortModeProvider(scope.playlistId!));

    // The repository stream already delivers the final provider-default
    // order; pass it through without a second full Dart sort.
    if (mode == ChannelSortMode.providerDefault) return channels;

    final playlistOrder = ref.watch(
      playlistCatalogPlaylistOrderProvider(scope),
    );
    // Alphabetical/numeric resorting runs off the critical first frame; the
    // previous result stays visible meanwhile.
    await Future<void>.delayed(Duration.zero);
    if (generation != _generation) {
      return state.valueOrNull ?? channels;
    }
    return sortPlaylistCatalogChannels(
      channels: channels,
      mode: mode,
      playlistOrder: playlistOrder,
    );
  }
}
