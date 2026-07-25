import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';

/// Playlist currently focused by the management UI. It is intentionally
/// independent from [selectedPlaylistIdProvider], which drives playback and
/// the Live catalogue.
final managedPlaylistIdProvider = StateProvider<int?>((ref) => null);

final playlistManagementControllerProvider =
    Provider<PlaylistManagementController>(PlaylistManagementController.new);

class PlaylistManagementController {
  const PlaylistManagementController(this._ref);

  final Ref _ref;

  /// Switches catalogue browsing to all currently active playlists while
  /// leaving the concrete selected playlist intact for playback/detail work.
  void selectAllActive() {
    _ref.read(playlistCatalogScopeProvider.notifier).state =
        const PlaylistCatalogScope.allActive();
  }

  Future<void> selectPlaylist(
    int playlistId, {
    bool activateIfNeeded = true,
    bool navigateToLive = true,
  }) async {
    final inactiveIds =
        _ref.read(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
    _ref.read(playlistCatalogScopeProvider.notifier).state =
        PlaylistCatalogScope.single(playlistId);
    _ref.read(selectedPlaylistIdProvider.notifier).state = playlistId;
    _resetSelectedGroupState(playlistId);
    if (activateIfNeeded && inactiveIds.contains(playlistId)) {
      await _ref
          .read(inactivePlaylistIdsProvider.notifier)
          .setActive(playlistId, true);
    }
    if (navigateToLive) navigateToLiveTab();
  }

  Future<void> setActive(int playlistId, bool active) async {
    if (!active && _ref.read(selectedPlaylistIdProvider) == playlistId) {
      final selectedChannel = _ref.read(selectedChannelProvider);
      if (selectedChannel?.playlistId == playlistId) {
        _ref.read(selectedChannelProvider.notifier).state = null;
      }
    }

    final persistence = _ref
        .read(inactivePlaylistIdsProvider.notifier)
        .setActive(playlistId, active);

    if (active || _ref.read(selectedPlaylistIdProvider) != playlistId) {
      await persistence;
      return;
    }

    final playlists =
        _ref.read(playlistsStreamProvider).valueOrNull ?? const [];
    final inactiveIds = {
      ...(_ref.read(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{}),
      playlistId,
    };
    final fallback = firstActivePlaylistId(playlists, inactiveIds);
    _ref.read(selectedPlaylistIdProvider.notifier).state = fallback;
    final scope = _ref.read(playlistCatalogScopeProvider);
    if (scope?.playlistId == playlistId) {
      _ref.read(playlistCatalogScopeProvider.notifier).state = fallback == null
          ? const PlaylistCatalogScope.allActive()
          : PlaylistCatalogScope.single(fallback);
    }
    if (fallback == null) {
      _ref.read(selectedGroupFilterProvider.notifier).state = kAllGroupsFilter;
    } else {
      _resetSelectedGroupState(fallback);
    }
    await persistence;
  }

  void focusManagement(int playlistId) {
    _ref.read(managedPlaylistIdProvider.notifier).state = playlistId;
  }

  void openManagement({int? playlistId}) {
    if (playlistId != null) focusManagement(playlistId);
    _ref.read(activeSidebarIndexProvider.notifier).state =
        shellPlaylistsTabIndex;
  }

  void openManagementForAdd() {
    _ref.read(managedPlaylistIdProvider.notifier).state = null;
    _ref.read(activeSidebarIndexProvider.notifier).state =
        shellPlaylistsTabIndex;
  }

  void navigateToLiveTab() {
    _ref.read(activeSidebarIndexProvider.notifier).state = shellLiveTabIndex;
  }

  Future<void> deletePlaylist(int playlistId) async {
    final selectedChannel = _ref.read(selectedChannelProvider);
    if (selectedChannel?.playlistId == playlistId) {
      _ref.read(selectedChannelProvider.notifier).state = null;
    }

    await _ref.read(playlistRepositoryProvider).deletePlaylist(playlistId);
    await _ref
        .read(appStateRepositoryProvider)
        .clearEpgRefreshInterval(playlistId);
    await _ref
        .read(inactivePlaylistIdsProvider.notifier)
        .removePlaylist(playlistId);

    if (_ref.read(managedPlaylistIdProvider) == playlistId) {
      _ref.read(managedPlaylistIdProvider.notifier).state = null;
    }
    if (_ref.read(selectedPlaylistIdProvider) == playlistId) {
      final remaining = await _ref
          .read(playlistRepositoryProvider)
          .getAllPlaylists();
      final inactiveIds =
          _ref.read(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
      final fallback = firstActivePlaylistId(remaining, inactiveIds);
      _ref.read(selectedPlaylistIdProvider.notifier).state = fallback;
      _ref.read(playlistCatalogScopeProvider.notifier).state = fallback == null
          ? const PlaylistCatalogScope.allActive()
          : PlaylistCatalogScope.single(fallback);
      if (fallback == null) {
        _ref.read(selectedGroupFilterProvider.notifier).state =
            kAllGroupsFilter;
      } else {
        _resetSelectedGroupState(fallback);
      }
    }
  }

  void _resetSelectedGroupState(int playlistId) {
    _ref.read(selectedGroupFilterProvider.notifier).state = kAllGroupsFilter;
    _ref.invalidate(hiddenGroupsForPlaylistProvider(playlistId));
    _ref.invalidate(pinnedGroupsForPlaylistProvider(playlistId));
  }
}
