import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/services/channel_sorting.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

export 'package:m3uxtream_player/core/models/channel_sort_mode.dart';

final channelSortModeProvider = StateNotifierProvider.autoDispose
    .family<ChannelSortModeNotifier, ChannelSortMode, int>((ref, playlistId) {
      return ChannelSortModeNotifier(
        playlistId,
        ref.read(appStateRepositoryProvider),
      );
    });

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

final sortedFilteredChannelsProvider = Provider.autoDispose<List<Channel>>((
  ref,
) {
  final channels = ref.watch(filteredChannelsProvider);
  final playlistId = ref.watch(selectedPlaylistIdProvider);
  if (playlistId == null) return channels;
  final mode = ref.watch(channelSortModeProvider(playlistId));
  return sortChannels(channels, mode);
});
