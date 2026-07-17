import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_hub_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';

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
    final channelsAsync = ref.watch(channelsStreamProvider);

    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Failed to load playlists: $err')),
      data: (playlists) {
        if (playlists.isEmpty) {
          return const _EmptyPlaylists();
        }

        final activeId = selectedId != null && !inactiveIds.contains(selectedId)
            ? selectedId
            : firstActivePlaylistId(playlists, inactiveIds);
        final activePlaylistId = activeId;
        final selectedFilter = ref.watch(selectedPlaylistContentFilterProvider);
        final hidden = ref.watch(hiddenGroupsProvider).valueOrNull ?? {};
        final pinned =
            ref.watch(pinnedGroupsProvider).valueOrNull ?? const <String>[];
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
              onVisibilityChanged: (visible) {
                final playlistId = activePlaylistId;
                if (playlistId == null) return;
                ref
                    .read(hiddenGroupsProvider.notifier)
                    .toggleGroup(playlistId, group, visible);
              },
              onPinChanged: (shouldPin) {
                final playlistId = activePlaylistId;
                if (playlistId == null) return;
                ref
                    .read(pinnedGroupsProvider.notifier)
                    .toggleGroup(playlistId, group, shouldPin);
              },
            ),
          );
        }

        return Row(
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
                    const _SectionTitle(
                      icon: Icons.playlist_play_rounded,
                      label: 'Playlists',
                      subtitle:
                          'Switch the active source and keep one playlist in focus.',
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: playlists.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          final isActive = playlist.id == activeId;
                          final isInactive = inactiveIds.contains(playlist.id);
                          return _PlaylistTile(
                            playlist: playlist,
                            isActive: isActive,
                            isInactive: isInactive,
                            onTap: () async {
                              if (isInactive) {
                                await ref
                                    .read(inactivePlaylistIdsProvider.notifier)
                                    .setActive(playlist.id, true);
                              }
                              ref
                                      .read(selectedPlaylistIdProvider.notifier)
                                      .state =
                                  playlist.id;
                              ref
                                      .read(
                                        selectedGroupFilterProvider.notifier,
                                      )
                                      .state =
                                  kAllGroupsFilter;
                              await ref
                                  .read(hiddenGroupsProvider.notifier)
                                  .reloadForPlaylist(playlist.id);
                              await ref
                                  .read(pinnedGroupsProvider.notifier)
                                  .reloadForPlaylist(playlist.id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: AppSurface(
                level: AppSurfaceLevel.high,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      icon: Icons.layers_rounded,
                      label: 'Category visibility',
                      subtitle:
                          'Pin what matters, hide what is not needed, and keep the same order everywhere.',
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
                                          ? 'Sync the playlist to load categories.'
                                          : selectedFilter.emptyMessage
                                    : selectedFilter.emptyMessage,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : CustomScrollView(
                              slivers: [
                                SliverToBoxAdapter(
                                  child: _CategoryBulkActionsRow(
                                    scopeLabel: selectedFilter.bulkLabelSuffix,
                                    hasVisibleGroups: visibleGroups.isNotEmpty,
                                    hasHiddenGroups: hidden.isNotEmpty,
                                    onHideAll:
                                        activePlaylistId == null ||
                                            allGroups.isEmpty
                                        ? null
                                        : () {
                                            final playlistId = activePlaylistId;
                                            ref
                                                .read(
                                                  hiddenGroupsProvider.notifier,
                                                )
                                                .setHidden(playlistId, {
                                                  ...hidden,
                                                  ...allGroups,
                                                });
                                          },
                                    onShowAll:
                                        activePlaylistId == null ||
                                            hidden.isEmpty
                                        ? null
                                        : () {
                                            final playlistId = activePlaylistId;
                                            ref
                                                .read(
                                                  hiddenGroupsProvider.notifier,
                                                )
                                                .setHidden(
                                                  playlistId,
                                                  hidden.difference(
                                                    allGroups.toSet(),
                                                  ),
                                                );
                                          },
                                  ),
                                ),
                                if (visibleGroups.isNotEmpty) ...[
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 14),
                                  ),
                                  const SliverToBoxAdapter(
                                    child: _SectionLabel(
                                      label: 'Visible categories',
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
                                  const SliverToBoxAdapter(
                                    child: _SectionLabel(
                                      label: 'Hidden categories',
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label, this.subtitle});

  final IconData icon;
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
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
            label: filter.label,
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
    required this.isActive,
    required this.isInactive,
    required this.onTap,
  });

  final Playlist playlist;
  final bool isActive;
  final bool isInactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final playlistAccent = playlist.type == 'xtream'
        ? colors.secondary
        : colors.primary;
    return M3MediaListItem(
      title: playlist.name,
      elevation: AppElevation.level1,
      selected: isActive,
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
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            playlist.type.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          M3StatusPill(
            label: isInactive ? 'Inactive' : 'Active',
            accent: isInactive ? colors.outlineVariant : colors.secondary,
            foreground: isInactive
                ? colors.onSurfaceVariant
                : colors.onSecondaryContainer,
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
  });

  final String label;
  final Color accent;
  final bool isVisible;
  final bool isPinned;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<bool> onPinChanged;

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
                      ? 'Visible in all category sidebars'
                      : 'Hidden from sidebar lists',
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
            tooltip: isPinned ? 'Unpin category' : 'Pin category',
            active: isPinned,
            onTap: () => onPinChanged(!isPinned),
          ),
          const SizedBox(width: 8),
          Switch(value: isVisible, onChanged: onVisibilityChanged),
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
            label: 'Visible',
            value: visibleCount.toString(),
            accent: colors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: 'Pinned',
            value: pinnedVisibleCount.toString(),
            accent: colors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: 'Hidden',
            value: hiddenCount.toString(),
            accent: colors.tertiary,
          ),
        ),
        if (pinnedHiddenCount > 0) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryMetric(
              label: 'Hidden pinned',
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
    required this.scopeLabel,
    required this.hasVisibleGroups,
    required this.hasHiddenGroups,
    required this.onHideAll,
    required this.onShowAll,
  });

  final String scopeLabel;
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
            label: Text(
              'Hide ${scopeLabel == 'all categories' ? 'all' : scopeLabel}',
            ),
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
            label: Text(
              'Show ${scopeLabel == 'all categories' ? 'all' : scopeLabel}',
            ),
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
  const _EmptyPlaylists();

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
            const Text(
              'No playlists yet',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a playlist in Settings, then manage it here.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
