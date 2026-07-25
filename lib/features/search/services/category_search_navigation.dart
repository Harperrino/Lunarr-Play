import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/xtream/providers/media_library_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/vod_providers.dart';

final categorySearchNavigationControllerProvider =
    Provider<CategorySearchNavigationController>(
      CategorySearchNavigationController.new,
    );

/// Opens a category result without touching the player or selected stream.
class CategorySearchNavigationController {
  const CategorySearchNavigationController(this._ref);

  final Ref _ref;

  void open(CategorySearchResult result) {
    // These are catalogue-only views. Clearing them does not stop or reset
    // the player, so an active stream remains untouched while navigation moves.
    _ref.read(playbackPrepControllerProvider.notifier).clearSelection();
    _ref.read(selectedSeriesChannelProvider.notifier).state = null;
    _ref.read(selectedPlaylistIdProvider.notifier).state = result.playlistId;

    switch (result.target) {
      case CategorySearchTarget.live:
        _ref.read(selectedGroupFilterProvider.notifier).state =
            result.categoryName;
        _ref.read(activeSidebarIndexProvider.notifier).state =
            shellLiveTabIndex;
      case CategorySearchTarget.movies:
        _ref.read(selectedVodGroupFilterProvider.notifier).state =
            result.categoryName;
        _ref.read(mediaLibraryTabProvider.notifier).state =
            mediaLibraryMoviesTabIndex;
        _ref.read(activeSidebarIndexProvider.notifier).state =
            shellMediaLibraryTabIndex;
      case CategorySearchTarget.series:
        _ref.read(selectedSeriesGroupFilterProvider.notifier).state =
            result.categoryName;
        _ref.read(mediaLibraryTabProvider.notifier).state =
            mediaLibrarySeriesTabIndex;
        _ref.read(activeSidebarIndexProvider.notifier).state =
            shellMediaLibraryTabIndex;
    }
  }

  /// Opens a live search result through the same selected-channel and player
  /// path as the existing live list, exactly once.
  Future<void> openChannel(ChannelSearchResult result) async {
    final channel = await _ref
        .read(playlistRepositoryProvider)
        .getChannelById(result.channelId);
    if (channel == null) return;

    _ref.read(playbackPrepControllerProvider.notifier).clearSelection();
    _ref.read(selectedSeriesChannelProvider.notifier).state = null;
    _ref.read(selectedPlaylistIdProvider.notifier).state = result.playlistId;
    _ref.read(selectedGroupFilterProvider.notifier).state = result.categoryName;
    _ref.read(selectedChannelProvider.notifier).state = channel;
    await _ref
        .read(playerNotifierProvider.notifier)
        .openStream(channel.streamUrl);
    _ref.read(activeSidebarIndexProvider.notifier).state = shellLiveTabIndex;
  }
}
