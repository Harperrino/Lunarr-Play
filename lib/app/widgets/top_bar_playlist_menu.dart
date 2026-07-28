import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';
import 'package:m3uxtream_player/app/controllers/playlist_management_controller.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Playlist selector for the shared desktop title bar.
class TopBarPlaylistMenu extends ConsumerWidget {
  const TopBarPlaylistMenu({super.key, required this.availableWidth});

  final double availableWidth;

  static double widthFor(double width) {
    if (width < 1080) return 48;
    if (width < 1240) return 196;
    return 248;
  }

  bool get _iconOnly => availableWidth < 1080;
  bool get _compact => availableWidth < 1240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final inactiveIds =
        ref.watch(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
    final databaseUnavailable = ref.watch(databaseHealthProvider).isFatal;
    final width = widthFor(availableWidth);

    return SizedBox(
      width: width,
      child: playlistsAsync.when(
        loading: () => _Trigger(
          width: width,
          iconOnly: _iconOnly,
          compact: _compact,
          label: context.l10n.playlistMenuTitle,
          active: false,
          onPressed: null,
        ),
        error: (_, _) => _Trigger(
          width: width,
          iconOnly: _iconOnly,
          compact: _compact,
          label: context.l10n.playlistMenuTitle,
          active: false,
          onPressed: ref
              .read(playlistManagementControllerProvider)
              .openManagementForAdd,
        ),
        data: (playlists) {
          final selectedId = ref.watch(selectedPlaylistIdProvider);
          final current = _currentPlaylist(playlists, inactiveIds, selectedId);
          final allSelected =
              ref.watch(playlistCatalogScopeProvider)?.isAllActive ?? false;
          late MenuController menuController;
          final menu = _PlaylistMenuSurface(
            playlists: playlists,
            inactiveIds: inactiveIds,
            selectedId: allSelected ? null : current?.id,
            allSelected: allSelected,
            databaseUnavailable: databaseUnavailable,
            closeMenu: () => menuController.close(),
            onSelectAll: () {
              ref.read(playlistManagementControllerProvider).selectAllActive();
              menuController.close();
            },
            onSelect: (id) async {
              await ref
                  .read(playlistManagementControllerProvider)
                  .selectPlaylist(id, navigateToLive: false);
            },
            onActiveChanged: (id, active) => unawaited(
              ref
                  .read(playlistManagementControllerProvider)
                  .setActive(id, active),
            ),
            onSync: (id) => unawaited(
              ref.read(playlistSyncNotifierProvider.notifier).sync(id),
            ),
            onManage: (id) {
              ref
                  .read(playlistManagementControllerProvider)
                  .openManagement(playlistId: id);
            },
          );

          if (playlists.isEmpty) {
            return _Trigger(
              width: width,
              iconOnly: _iconOnly,
              compact: _compact,
              label: context.l10n.playlistMenuAdd,
              active: false,
              onPressed: ref
                  .read(playlistManagementControllerProvider)
                  .openManagementForAdd,
            );
          }

          return MenuAnchor(
            menuChildren: [menu],
            builder: (context, controller, child) {
              menuController = controller;
              return _Trigger(
                width: width,
                iconOnly: _iconOnly,
                compact: _compact,
                label: allSelected
                    ? context.l10n.playlistMenuAllActiveSelection
                    : current?.name ?? context.l10n.playlistMenuChoose,
                active: current != null,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  static Playlist? _currentPlaylist(
    List<Playlist> playlists,
    Set<int> inactiveIds,
    int? selectedId,
  ) {
    Playlist? selected;
    for (final playlist in playlists) {
      if (playlist.id == selectedId) {
        selected = playlist;
        break;
      }
    }
    if (selected != null) return selected;
    for (final playlist in playlists) {
      if (!inactiveIds.contains(playlist.id)) return playlist;
    }
    return selected;
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({
    required this.width,
    required this.iconOnly,
    required this.compact,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final double width;
  final bool iconOnly;
  final bool compact;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final button = IconButton(
      tooltip: iconOnly ? label : null,
      onPressed: onPressed,
      icon: Icon(
        iconOnly ? Icons.playlist_play_rounded : Icons.playlist_play_rounded,
        color: active ? colors.primary : colors.onSurfaceVariant,
      ),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        minimumSize: const Size.square(48),
        padding: EdgeInsets.zero,
      ),
    );
    if (iconOnly) return button;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: width,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_play_rounded,
                    size: 20,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: M3StatusPill(
                        label: active
                            ? context.l10n.playlistMenuStatusActive
                            : context.l10n.playlistMenuStatusInactive,
                        accent: active ? colors.secondary : colors.outline,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistMenuSurface extends ConsumerWidget {
  const _PlaylistMenuSurface({
    required this.playlists,
    required this.inactiveIds,
    required this.selectedId,
    required this.allSelected,
    required this.databaseUnavailable,
    required this.closeMenu,
    required this.onSelectAll,
    required this.onSelect,
    required this.onActiveChanged,
    required this.onSync,
    required this.onManage,
  });

  final List<Playlist> playlists;
  final Set<int> inactiveIds;
  final int? selectedId;
  final bool allSelected;
  final bool databaseUnavailable;
  final VoidCallback closeMenu;
  final VoidCallback onSelectAll;
  final Future<void> Function(int id) onSelect;
  final void Function(int id, bool active) onActiveChanged;
  final ValueChanged<int> onSync;
  final ValueChanged<int> onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      width: 360,
      padding: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Text(
                  context.l10n.playlistMenuTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              _AllActiveMenuRow(isSelected: allSelected, onSelect: onSelectAll),
              for (final playlist in playlists)
                _PlaylistMenuRow(
                  playlist: playlist,
                  isSelected: playlist.id == selectedId,
                  isActive: !inactiveIds.contains(playlist.id),
                  syncState: ref.watch(playlistSyncStatusProvider(playlist.id)),
                  databaseUnavailable: databaseUnavailable,
                  onSelect: () async {
                    await onSelect(playlist.id);
                    closeMenu();
                  },
                  onActiveChanged: (active) =>
                      onActiveChanged(playlist.id, active),
                  onSync: () => onSync(playlist.id),
                  onManage: () {
                    closeMenu();
                    onManage(playlist.id);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllActiveMenuRow extends StatelessWidget {
  const _AllActiveMenuRow({required this.isSelected, required this.onSelect});

  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: isSelected ? colors.primary : colors.outline,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.all_inclusive_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.playlistMenuAllLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                context.l10n.playlistMenuActivePlaylistsSubtitle,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistMenuRow extends StatelessWidget {
  const _PlaylistMenuRow({
    required this.playlist,
    required this.isSelected,
    required this.isActive,
    required this.syncState,
    required this.databaseUnavailable,
    required this.onSelect,
    required this.onActiveChanged,
    required this.onSync,
    required this.onManage,
  });

  final Playlist playlist;
  final bool isSelected;
  final bool isActive;
  final AsyncValue<void> syncState;
  final bool databaseUnavailable;
  final Future<void> Function() onSelect;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSync;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: databaseUnavailable ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: isSelected ? colors.primary : colors.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      syncState.isLoading
                          ? context.l10n.playlistMenuSyncing
                          : syncState.hasError
                          ? context.l10n.playlistMenuSyncFailed
                          : isActive
                          ? context.l10n.playlistMenuStatusActive
                          : context.l10n.playlistMenuStatusInactive,
                      style: TextStyle(
                        fontSize: 10,
                        color: syncState.hasError
                            ? colors.error
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: databaseUnavailable ? null : onActiveChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              IconButton(
                tooltip: context.l10n.playlistMenuSyncTooltip,
                onPressed: databaseUnavailable || syncState.isLoading
                    ? null
                    : onSync,
                icon: syncState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
              ),
              IconButton(
                tooltip: context.l10n.playlistMenuManageTooltip,
                onPressed: databaseUnavailable ? null : onManage,
                icon: const Icon(Icons.settings_outlined, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
