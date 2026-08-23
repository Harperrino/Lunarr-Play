import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/core/models/playlist_epg.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/app/controllers/playlist_management_controller.dart';
import 'package:m3uxtream_player/features/playlists/providers/managed_playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/app/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_hub_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/app/widgets/playlist_management_dialogs.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Playlists hub — switch active playlist and manage category visibility.
class PlaylistHubScreen extends ConsumerWidget {
  const PlaylistHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _ensureActiveSelection(ref);
    final colors = Theme.of(context).colorScheme;

    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final selectedId = ref.watch(selectedPlaylistIdProvider);
    final inactiveIds =
        ref.watch(inactivePlaylistIdsProvider).valueOrNull ?? const <int>{};
    final databaseUnavailable = ref.watch(databaseHealthProvider).isFatal;
    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) =>
          Center(child: Text(context.l10n.playlistHubLoadError('$err'))),
      data: (playlists) {
        if (playlists.isEmpty) {
          return _EmptyPlaylists(onAdd: () => showPlaylistAddDialog(context));
        }

        final selectedRowId =
            selectedId != null &&
                playlists.any((playlist) => playlist.id == selectedId)
            ? selectedId
            : firstActivePlaylistId(playlists, inactiveIds);
        final managementId = managementPlaylistId(
          playlists: playlists,
          inactiveIds: inactiveIds,
          managedId: ref.watch(managedPlaylistIdProvider),
          selectedId: selectedId,
        );
        final channelsAsync = managementId == null
            ? const AsyncData<List<Channel>>([])
            : ref.watch(managedPlaylistChannelsProvider(managementId));
        final hiddenAsync = managementId == null
            ? const AsyncData<Set<String>>({})
            : ref.watch(managedHiddenGroupsProvider(managementId));
        final pinnedAsync = managementId == null
            ? const AsyncData<List<String>>([])
            : ref.watch(managedPinnedGroupsProvider(managementId));
        final selectedFilter = ref.watch(selectedPlaylistContentFilterProvider);
        final hidden = hiddenAsync.valueOrNull ?? <String>{};
        final pinned = pinnedAsync.valueOrNull ?? const <String>[];
        final categoryData = buildPlaylistHubCategoryViewData(
          channels: channelsAsync.valueOrNull ?? const <Channel>[],
          contentFilter: selectedFilter,
          hiddenGroups: hidden,
          pinnedGroups: pinned,
        );
        final allGroups = categoryData.allGroups;
        final visibleGroups = categoryData.visibleGroups;
        final hiddenGroupsList = categoryData.hiddenGroups;

        Widget categoryTile(String group, {required bool isVisible}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _CategoryVisibilityTile(
              label: group,
              accent: GroupAccent.forGroup(group),
              isVisible: isVisible,
              isPinned: categoryData.pinnedGroups.contains(group),
              databaseUnavailable: databaseUnavailable,
              onVisibilityChanged: (visible) {
                final playlistId = managementId;
                if (playlistId == null) return;
                unawaited(
                  ref
                      .read(appStateRepositoryProvider)
                      .getHiddenGroups(playlistId)
                      .then((current) async {
                        if (visible) {
                          current.remove(group);
                        } else {
                          current.add(group);
                        }
                        await ref
                            .read(appStateRepositoryProvider)
                            .setHiddenGroups(playlistId, current);
                        ref.invalidate(managedHiddenGroupsProvider(playlistId));
                      }),
                );
              },
              onPinChanged: (shouldPin) {
                final playlistId = managementId;
                if (playlistId == null) return;
                unawaited(
                  ref
                      .read(appStateRepositoryProvider)
                      .getPinnedGroups(playlistId)
                      .then((current) async {
                        if (shouldPin) {
                          current.remove(group);
                          current.add(group);
                        } else {
                          current.remove(group);
                        }
                        await ref
                            .read(appStateRepositoryProvider)
                            .setPinnedGroups(playlistId, current);
                        ref.invalidate(managedPinnedGroupsProvider(playlistId));
                      }),
                );
              },
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final stackPanels = constraints.maxWidth < 900;
            return Flex(
              direction: stackPanels ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: AppSurface(
                    level: AppSurfaceLevel.high,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.playlist_play_rounded,
                          label: context.l10n.playlistHubTitle,
                          subtitle: context.l10n.playlistHubSubtitle,
                          action: FilledButton.icon(
                            onPressed: () => showPlaylistAddDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(context.l10n.playlistHubAdd),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView.separated(
                            itemCount: playlists.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final playlist = playlists[index];
                              final isSelected = playlist.id == selectedRowId;
                              final isInactive = inactiveIds.contains(
                                playlist.id,
                              );
                              final epgJobs =
                                  ref.watch(epgSyncJobsProvider).valueOrNull ??
                                  const <int, EpgSyncJob>{};
                              final syncState = ref.watch(
                                playlistSyncStatusProvider(playlist.id),
                              );
                              final epgInterval = ref.watch(
                                epgRefreshIntervalProvider(playlist.id),
                              );
                              return _PlaylistTile(
                                playlist: playlist,
                                isSelected: isSelected,
                                isInactive: isInactive,
                                syncState: syncState,
                                epgJob: epgJobs[playlist.id],
                                hasEpgUrl: playlist.effectiveEpgUrl != null,
                                epgInterval: epgInterval,
                                databaseUnavailable: databaseUnavailable,
                                onTap: () => unawaited(
                                  ref
                                      .read(
                                        playlistManagementControllerProvider,
                                      )
                                      .selectPlaylist(playlist.id),
                                ),
                                onActiveChanged: (active) => unawaited(
                                  ref
                                      .read(
                                        playlistManagementControllerProvider,
                                      )
                                      .setActive(playlist.id, active),
                                ),
                                onSync: () => unawaited(
                                  ref
                                      .read(
                                        playlistSyncNotifierProvider.notifier,
                                      )
                                      .sync(playlist.id),
                                ),
                                onEpgSync: () => unawaited(
                                  ref
                                      .read(epgSyncControllerProvider)
                                      .enqueue(playlist.id)
                                      .catchError((_) {}),
                                ),
                                onEpgIntervalChanged: (interval) => unawaited(
                                  ref
                                      .read(
                                        epgRefreshIntervalProvider(playlist.id)
                                            .notifier,
                                      )
                                      .setInterval(interval),
                                ),
                                onEdit: () =>
                                    showPlaylistEditDialog(context, playlist),
                                onDelete: () =>
                                    _confirmDelete(context, ref, playlist),
                                onManage: () => ref
                                    .read(playlistManagementControllerProvider)
                                    .openManagement(playlistId: playlist.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: stackPanels ? 0 : 16,
                  height: stackPanels ? 16 : 0,
                ),
                Expanded(
                  flex: 3,
                  child: AppSurface(
                    level: AppSurfaceLevel.high,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.layers_rounded,
                          label:
                              context.l10n.playlistHubCategoryVisibilityTitle,
                          subtitle: context
                              .l10n
                              .playlistHubCategoryVisibilitySubtitle,
                        ),
                        const SizedBox(height: 14),
                        _ContentTypeFilterBar(
                          selectedFilter: selectedFilter,
                          onSelected: (filter) =>
                              ref
                                      .read(
                                        selectedPlaylistContentFilterProvider
                                            .notifier,
                                      )
                                      .state =
                                  filter,
                        ),
                        const SizedBox(height: 12),
                        _CategorySummaryRow(
                          visibleCount: visibleGroups.length,
                          hiddenCount: hiddenGroupsList.length,
                          pinnedVisibleCount: categoryData.pinnedVisibleCount,
                          pinnedHiddenCount: categoryData.pinnedHiddenCount,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: allGroups.isEmpty
                              ? Center(
                                  child: Text(
                                    categoryData.matchingChannelCount == 0
                                        ? selectedFilter ==
                                                  PlaylistContentFilter.all
                                              ? context
                                                    .l10n
                                                    .playlistHubSyncToLoadCategories
                                              : _playlistContentFilterEmptyMessage(
                                                  context,
                                                  selectedFilter,
                                                )
                                        : _playlistContentFilterEmptyMessage(
                                            context,
                                            selectedFilter,
                                          ),
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : CustomScrollView(
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: _CategoryBulkActionsRow(
                                        hideLabel:
                                            _playlistContentFilterHideActionLabel(
                                              context,
                                              selectedFilter,
                                            ),
                                        showLabel:
                                            _playlistContentFilterShowActionLabel(
                                              context,
                                              selectedFilter,
                                            ),
                                        hasVisibleGroups:
                                            visibleGroups.isNotEmpty,
                                        hasHiddenGroups: hidden.isNotEmpty,
                                        onHideAll:
                                            managementId == null ||
                                                allGroups.isEmpty
                                            ? null
                                            : () => unawaited(
                                                _setManagedHiddenGroups(
                                                  ref,
                                                  managementId,
                                                  {...hidden, ...allGroups},
                                                ),
                                              ),
                                        onShowAll:
                                            managementId == null ||
                                                hidden.isEmpty
                                            ? null
                                            : () => unawaited(
                                                _setManagedHiddenGroups(
                                                  ref,
                                                  managementId,
                                                  hidden.difference(
                                                    allGroups.toSet(),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    if (visibleGroups.isNotEmpty) ...[
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 14),
                                      ),
                                      SliverToBoxAdapter(
                                        child: _SectionLabel(
                                          label: context
                                              .l10n
                                              .playlistHubVisibleCategoriesSection,
                                        ),
                                      ),
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 10),
                                      ),
                                      SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) => categoryTile(
                                            visibleGroups[index],
                                            isVisible: true,
                                          ),
                                          childCount: visibleGroups.length,
                                        ),
                                      ),
                                    ],
                                    if (hiddenGroupsList.isNotEmpty) ...[
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 18),
                                      ),
                                      SliverToBoxAdapter(
                                        child: _SectionLabel(
                                          label: context
                                              .l10n
                                              .playlistHubHiddenCategoriesSection,
                                        ),
                                      ),
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 10),
                                      ),
                                      SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) => categoryTile(
                                            hiddenGroupsList[index],
                                            isVisible: false,
                                          ),
                                          childCount: hiddenGroupsList.length,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _ensureActiveSelection(WidgetRef ref) {
    void syncSelection() {
      final playlists = ref.read(playlistsStreamProvider).valueOrNull;
      final inactiveIds = ref.read(inactivePlaylistIdsProvider).valueOrNull;
      if (playlists == null || inactiveIds == null) return;
      normalizeSelectedPlaylist(ref, playlists, inactiveIds);
    }

    ref.listen(playlistsStreamProvider, (_, _) => syncSelection());
    ref.listen(inactivePlaylistIdsProvider, (_, _) => syncSelection());
    SchedulerBinding.instance.addPostFrameCallback((_) => syncSelection());
  }

  Future<void> _setManagedHiddenGroups(
    WidgetRef ref,
    int playlistId,
    Set<String> groups,
  ) async {
    await ref
        .read(appStateRepositoryProvider)
        .setHiddenGroups(playlistId, groups);
    ref.invalidate(managedHiddenGroupsProvider(playlistId));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.playlistHubDeleteTitle),
        content: Text(context.l10n.playlistHubDeleteBody(playlist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.playlistHubDeleteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.playlistHubDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(playlistFormNotifierProvider.notifier)
          .deletePlaylist(playlist.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.playlistHubDeleteSuccess(playlist.name)),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.playlistHubDeleteFailure(error.toString()),
            ),
          ),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.label,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSurface(
          level: AppSurfaceLevel.low,
          width: 30,
          height: 30,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: colors.secondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final titleAction = action;
    if (titleAction == null) return heading;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: titleAction),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 8),
            titleAction,
          ],
        );
      },
    );
  }
}

class _ContentTypeFilterBar extends StatelessWidget {
  const _ContentTypeFilterBar({
    required this.selectedFilter,
    required this.onSelected,
  });

  final PlaylistContentFilter selectedFilter;
  final ValueChanged<PlaylistContentFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in PlaylistContentFilter.values)
          _ContentTypeFilterChip(
            label: _playlistContentFilterLabel(context, filter),
            selected: selectedFilter == filter,
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }
}

class _ContentTypeFilterChip extends StatelessWidget {
  const _ContentTypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      backgroundColor: colors.surfaceContainerHigh,
      selectedColor: colors.secondaryContainer,
      side: BorderSide(
        color: selected ? colors.secondary : colors.outlineVariant,
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.isSelected,
    required this.isInactive,
    required this.syncState,
    required this.epgJob,
    required this.hasEpgUrl,
    required this.epgInterval,
    required this.onTap,
    required this.onActiveChanged,
    required this.onSync,
    required this.onEpgSync,
    required this.onEpgIntervalChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onManage,
    required this.databaseUnavailable,
  });

  final Playlist playlist;
  final bool isSelected;
  final bool isInactive;
  final AsyncValue<void> syncState;
  final EpgSyncJob? epgJob;
  final bool hasEpgUrl;
  final EpgRefreshInterval epgInterval;
  final VoidCallback onTap;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSync;
  final VoidCallback onEpgSync;
  final ValueChanged<EpgRefreshInterval> onEpgIntervalChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManage;
  final bool databaseUnavailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final playlistAccent = playlist.type == 'xtream'
        ? colors.secondary
        : colors.primary;
    return M3MediaListItem(
      title: playlist.name,
      elevation: AppElevation.level1,
      selected: isSelected,
      onActivate: onTap,
      leading: AppSurface(
        level: AppSurfaceLevel.high,
        width: 36,
        height: 36,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Icon(
          playlist.type == 'xtream' ? Icons.dns_rounded : Icons.link_rounded,
          size: 16,
          color: playlistAccent,
        ),
      ),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            playlist.type.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          M3StatusPill(
            label: isInactive
                ? context.l10n.playlistHubStatusInactive
                : context.l10n.playlistHubStatusActive,
            accent: isInactive ? colors.outlineVariant : colors.secondary,
            foreground: isInactive
                ? colors.onSurfaceVariant
                : colors.onSecondaryContainer,
          ),
          if (syncState.isLoading)
            M3StatusPill(
              label: context.l10n.playlistHubStatusSyncing,
              accent: Colors.blue,
            ),
          if (epgJob?.isActive ?? false)
            M3StatusPill(
              label: context.l10n.playlistHubStatusEpgSyncing,
              accent: Colors.deepPurple,
            ),
          if (epgJob?.status == EpgSyncStatus.failed)
            M3StatusPill(
              label: context.l10n.playlistHubStatusEpgError,
              accent: colors.error,
            ),
          if (hasEpgUrl &&
              !(epgJob?.isActive ?? false) &&
              epgJob?.status != EpgSyncStatus.failed)
            M3StatusPill(
              label: epgInterval.isAutomatic
                  ? context.l10n.playlistHubStatusEpgInterval(
                      _epgRefreshIntervalLabel(context, epgInterval),
                    )
                  : context.l10n.playlistHubStatusEpgReady,
              accent: colors.tertiary,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: !isInactive,
            onChanged: databaseUnavailable ? null : onActiveChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          IconButton(
            tooltip: context.l10n.playlistHubSyncTooltip,
            onPressed: syncState.isLoading ? null : onSync,
            icon: syncState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.playlistHubMoreActionsTooltip,
            onSelected: (value) {
              switch (value) {
                case 'sync':
                  if (!syncState.isLoading) onSync();
                case 'epg-sync':
                  if (hasEpgUrl && !(epgJob?.isActive ?? false)) onEpgSync();
                case 'manage':
                  onManage();
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
                default:
                  if (value.startsWith('epg:')) {
                    onEpgIntervalChanged(
                      EpgRefreshInterval.fromStorage(value.substring(4)),
                    );
                  }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'sync',
                enabled: !syncState.isLoading,
                child: Row(
                  children: [
                    syncState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        context.l10n.playlistHubSyncAction,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'epg-sync',
                enabled: hasEpgUrl && !(epgJob?.isActive ?? false),
                child: Row(
                  children: [
                    epgJob?.isActive ?? false
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.calendar_month_rounded, size: 18),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        !hasEpgUrl
                            ? context.l10n.playlistHubNoEpgUrl
                            : epgJob?.status == EpgSyncStatus.failed
                            ? context.l10n.playlistHubRetryEpgAction
                            : context.l10n.playlistHubSyncEpgAction,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'manage',
                child: Text(context.l10n.playlistHubManageAction),
              ),
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(context.l10n.playlistHubEditAction),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(context.l10n.playlistHubDeleteAction),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                enabled: false,
                value: 'epg-label',
                child: Text(context.l10n.playlistHubAutomaticEpgTitle),
              ),
              for (final interval in EpgRefreshInterval.values)
                PopupMenuItem<String>(
                  value: 'epg:${interval.storageValue}',
                  child: Row(
                    children: [
                      if (interval == epgInterval) ...[
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(_epgRefreshIntervalLabel(context, interval)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryVisibilityTile extends StatelessWidget {
  const _CategoryVisibilityTile({
    required this.label,
    required this.accent,
    required this.isVisible,
    required this.isPinned,
    required this.onVisibilityChanged,
    required this.onPinChanged,
    required this.databaseUnavailable,
  });

  final String label;
  final Color accent;
  final bool isVisible;
  final bool isPinned;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<bool> onPinChanged;
  final bool databaseUnavailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isPinned
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isVisible
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isPinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(
                            alpha: isVisible ? 0.14 : 0.10,
                          ),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          Icons.push_pin_rounded,
                          size: 10,
                          color: isVisible
                              ? colors.onSurface
                              : accent.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isVisible
                      ? context.l10n.playlistHubCategoryVisibleDescription
                      : context.l10n.playlistHubCategoryHiddenDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _MiniAction(
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            tooltip: isPinned
                ? context.l10n.playlistHubUnpinCategoryTooltip
                : context.l10n.playlistHubPinCategoryTooltip,
            active: isPinned,
            onTap: () => onPinChanged(!isPinned),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isVisible,
            onChanged: databaseUnavailable ? null : onVisibilityChanged,
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      color: active ? colors.onSecondaryContainer : colors.onSurfaceVariant,
      style: IconButton.styleFrom(
        fixedSize: const Size(32, 32),
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        backgroundColor: active
            ? colors.secondaryContainer
            : colors.surfaceContainerHigh,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  const _CategorySummaryRow({
    required this.visibleCount,
    required this.hiddenCount,
    required this.pinnedVisibleCount,
    required this.pinnedHiddenCount,
  });

  final int visibleCount;
  final int hiddenCount;
  final int pinnedVisibleCount;
  final int pinnedHiddenCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _SummaryMetric(
            label: context.l10n.playlistHubSummaryVisible,
            value: visibleCount.toString(),
            accent: colors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: context.l10n.playlistHubSummaryPinned,
            value: pinnedVisibleCount.toString(),
            accent: colors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: context.l10n.playlistHubSummaryHidden,
            value: hiddenCount.toString(),
            accent: colors.tertiary,
          ),
        ),
        if (pinnedHiddenCount > 0) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryMetric(
              label: context.l10n.playlistHubSummaryHiddenPinned,
              value: pinnedHiddenCount.toString(),
              accent: colors.secondary,
              subdued: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.accent,
    this.subdued = false,
  });

  final String label;
  final String value;
  final Color accent;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: subdued ? AppSurfaceLevel.low : AppSurfaceLevel.standard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      surfaceColor: subdued
          ? colors.surfaceContainerLow
          : accent.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: accent.withValues(alpha: subdued ? 0.16 : 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}

class _CategoryBulkActionsRow extends StatelessWidget {
  const _CategoryBulkActionsRow({
    required this.hideLabel,
    required this.showLabel,
    required this.hasVisibleGroups,
    required this.hasHiddenGroups,
    required this.onHideAll,
    required this.onShowAll,
  });

  final String hideLabel;
  final String showLabel;
  final bool hasVisibleGroups;
  final bool hasHiddenGroups;
  final VoidCallback? onHideAll;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasVisibleGroups ? onHideAll : null,
            icon: const Icon(Icons.visibility_off_rounded, size: 16),
            label: Text(hideLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasHiddenGroups ? onShowAll : null,
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: Text(showLabel),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play_rounded,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.playlistHubEmptyTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.playlistHubEmptySubtitle,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.playlistHubAdd),
            ),
          ],
        ),
      ),
    );
  }
}

String _playlistContentFilterLabel(
  BuildContext context,
  PlaylistContentFilter filter,
) => switch (filter) {
  PlaylistContentFilter.all => context.l10n.playlistHubContentFilterAll,
  PlaylistContentFilter.live => context.l10n.playlistHubContentFilterLive,
  PlaylistContentFilter.vod => context.l10n.playlistHubContentFilterVod,
  PlaylistContentFilter.series => context.l10n.playlistHubContentFilterSeries,
};

String _playlistContentFilterEmptyMessage(
  BuildContext context,
  PlaylistContentFilter filter,
) => switch (filter) {
  PlaylistContentFilter.all => context.l10n.playlistHubEmptyCategoriesAll,
  PlaylistContentFilter.live => context.l10n.playlistHubEmptyCategoriesLive,
  PlaylistContentFilter.vod => context.l10n.playlistHubEmptyCategoriesVod,
  PlaylistContentFilter.series => context.l10n.playlistHubEmptyCategoriesSeries,
};

String _playlistContentFilterHideActionLabel(
  BuildContext context,
  PlaylistContentFilter filter,
) => switch (filter) {
  PlaylistContentFilter.all => context.l10n.playlistHubHideAllCategories,
  PlaylistContentFilter.live => context.l10n.playlistHubHideLiveCategories,
  PlaylistContentFilter.vod => context.l10n.playlistHubHideVodCategories,
  PlaylistContentFilter.series => context.l10n.playlistHubHideSeriesCategories,
};

String _playlistContentFilterShowActionLabel(
  BuildContext context,
  PlaylistContentFilter filter,
) => switch (filter) {
  PlaylistContentFilter.all => context.l10n.playlistHubShowAllCategories,
  PlaylistContentFilter.live => context.l10n.playlistHubShowLiveCategories,
  PlaylistContentFilter.vod => context.l10n.playlistHubShowVodCategories,
  PlaylistContentFilter.series => context.l10n.playlistHubShowSeriesCategories,
};

String _epgRefreshIntervalLabel(
  BuildContext context,
  EpgRefreshInterval interval,
) => switch (interval) {
  EpgRefreshInterval.manual => context.l10n.playlistHubEpgIntervalManual,
  EpgRefreshInterval.hours6 => context.l10n.playlistHubEpgIntervalHours6,
  EpgRefreshInterval.hours12 => context.l10n.playlistHubEpgIntervalHours12,
  EpgRefreshInterval.hours24 => context.l10n.playlistHubEpgIntervalHours24,
};
