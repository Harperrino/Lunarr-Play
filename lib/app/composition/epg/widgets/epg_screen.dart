import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/models/playlist_epg.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/widgets/epg_compact_agenda.dart';
import 'package:m3uxtream_player/app/composition/epg/widgets/epg_grid.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen_layout.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_toolbar.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_filters.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_filter_providers.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/shared/providers/app_shell_state_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_shimmer.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// EPG guide screen — sidebar index 2.
class EpgScreen extends ConsumerWidget {
  const EpgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(epgGridEntriesSnapshotProvider);
    final catalogAsync = ref.watch(knownEpgChannelIdsProvider);
    final rows = ref.watch(epgGridRowsProvider);
    final channels = ref.watch(epgGridChannelsProvider);
    final searchQuery = ref.watch(globalSearchQueryProvider).trim();
    final totalLiveCount =
        ref.watch(liveChannelsStreamProvider).valueOrNull?.length ?? 0;
    final epgJobs = ref.watch(epgSyncJobsProvider).valueOrNull ?? const {};
    final filterIds = ref.watch(epgFilterPlaylistIdsProvider);
    final playlists =
        ref.watch(playlistsStreamProvider).valueOrNull ?? const [];

    final sources = playlists
        .where((p) => filterIds.contains(p.id) && p.effectiveEpgUrl != null)
        .toList();
    final hasEpgUrl = sources.isNotEmpty;
    final categories = ref.watch(epgFilterCategoriesProvider);
    final selectedCategories = ref.watch(epgCategoryFilterProvider);
    Future<void> refresh() async {
      try {
        await Future.wait(
          sources.map((p) => ref.read(epgSyncControllerProvider).enqueue(p.id)),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.l10n.epgLoadError)));
        }
      }
    }

    void retry() {
      ref.invalidate(knownEpgChannelIdsProvider);
      ref.invalidate(epgChannelDisplayNamesProvider);
      ref.read(epgGridSnapshotCacheProvider).clear();
      ref.invalidate(epgGridSnapshotProvider);
    }

    final guideError =
        entriesAsync.hasError ||
        catalogAsync.hasError ||
        ref.watch(epgGuideChannelsProvider).hasError;
    final hasVisibleProgrammes = epgGridHasVisibleProgrammes(rows);
    final hasMatchedChannels = epgGridHasMatchedChannels(rows);
    final isManualSync = filterIds.any((id) => epgJobs[id]?.isActive ?? false);
    final guide = ref.watch(epgGuideChannelsProvider);
    final isInitialCatalogLoad =
        (catalogAsync.isLoading && !catalogAsync.hasValue) ||
        (guide.isLoading && (guide.valueOrNull?.isEmpty ?? true));
    final isEntriesLoading = entriesAsync.isLoading && !entriesAsync.hasValue;

    return AppSurface(
      key: const ValueKey('epg-screen-surface'),
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(20),
      child: EpgScreenLayout(
        toolbar: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EpgToolbar(
              isBusy: false,
              isEntriesLoading: isEntriesLoading || isManualSync,
              onJumpToNow: () => jumpEpgWindowToNow(ref),
              onBackTwoHours: () =>
                  shiftEpgWindow(ref, const Duration(hours: -2)),
              onForwardTwoHours: () =>
                  shiftEpgWindow(ref, const Duration(hours: 2)),
              onBackOneDay: () => shiftEpgWindow(ref, const Duration(days: -1)),
              onForwardOneDay: () =>
                  shiftEpgWindow(ref, const Duration(days: 1)),
              onZoomOut: () => adjustEpgGridPixelsPerMinute(ref, -0.25),
              onZoomIn: () => adjustEpgGridPixelsPerMinute(ref, 0.25),
              onResetZoom: () =>
                  setEpgGridPixelsPerMinute(ref, epgGridPixelsPerMinuteDefault),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EpgFilterButton<int>(
                  title: context.l10n.epgFilterPlaylists,
                  options: [
                    for (final p in playlists) EpgFilterOption(p.id, p.name),
                  ],
                  selected: filterIds.toSet(),
                  onChanged: (ids) {
                    ref.read(epgPlaylistFilterProvider.notifier).state = ids;
                    ref.read(epgCategoryFilterProvider.notifier).state = null;
                  },
                ),
                EpgFilterButton<String>(
                  title: context.l10n.epgFilterCategories,
                  options: [
                    for (final category in categories)
                      EpgFilterOption(
                        category.filterKey,
                        '${category.playlistName} · ${category.groupName}',
                      ),
                  ],
                  selected:
                      selectedCategories ??
                      categories.map((c) => c.filterKey).toSet(),
                  onChanged: (keys) =>
                      ref.read(epgCategoryFilterProvider.notifier).state = keys,
                ),
                TextButton(
                  onPressed: () {
                    ref.read(epgPlaylistFilterProvider.notifier).state = null;
                    ref.read(epgCategoryFilterProvider.notifier).state = null;
                  },
                  child: Text(context.l10n.epgFilterReset),
                ),
                FilledButton.tonalIcon(
                  onPressed: !hasEpgUrl || isManualSync
                      ? null
                      : () => unawaited(refresh()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.l10n.epgUpdateAction),
                ),
              ],
            ),
          ],
        ),
        body: guideError
            ? _EmptyState(
                icon: Icons.error_outline_rounded,
                title: context.l10n.epgLoadError,
                subtitle: context.l10n.epgRetrySubtitle,
                actionLabel: context.l10n.epgRetryAction,
                onAction: retry,
              )
            : _buildBody(
                context,
                ref,
                isInitialCatalogLoad: isInitialCatalogLoad,
                isEntriesLoading: isEntriesLoading,
                channelsEmpty: channels.isEmpty,
                searchQuery: searchQuery,
                totalLiveCount: totalLiveCount,
                hasVisibleProgrammes: hasVisibleProgrammes,
                hasMatchedChannels: hasMatchedChannels,
                hasEpgUrl: hasEpgUrl,
                selectedPlaylistId: sources.isEmpty ? null : sources.first.id,
                onRefresh: () => unawaited(refresh()),
                rows: rows,
              ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isInitialCatalogLoad,
    required bool isEntriesLoading,
    required bool channelsEmpty,
    required String searchQuery,
    required int totalLiveCount,
    required bool hasVisibleProgrammes,
    required bool hasMatchedChannels,
    required bool hasEpgUrl,
    required int? selectedPlaylistId,
    required VoidCallback onRefresh,
    required List<EpgGridRowData> rows,
  }) {
    if (isInitialCatalogLoad) {
      return _EpgGridShimmer(rowCount: rows.length.clamp(4, 10));
    }
    if (channelsEmpty) {
      if (searchQuery.isNotEmpty && totalLiveCount > 0) {
        return _EmptyState(
          icon: Icons.search_off_rounded,
          title: context.l10n.epgNoSearchResults,
          subtitle: context.l10n.epgClearSearchSubtitle(totalLiveCount),
        );
      }
      return _EmptyState(
        icon: Icons.playlist_play_rounded,
        title: context.l10n.epgNoChannelsTitle,
        subtitle: context.l10n.epgNoChannelsSubtitle,
      );
    }

    if (!hasVisibleProgrammes &&
        !hasMatchedChannels &&
        !isEntriesLoading &&
        rows.isNotEmpty) {
      return _EmptyState(
        icon: Icons.calendar_month_rounded,
        title: context.l10n.epgNoDataTitle,
        subtitle: hasEpgUrl
            ? context.l10n.epgUpdateGuideSubtitle
            : context.l10n.epgConfigureUrlSubtitle,
        actionLabel: hasEpgUrl && selectedPlaylistId != null
            ? context.l10n.epgUpdateAction
            : null,
        onAction: hasEpgUrl && selectedPlaylistId != null ? onRefresh : null,
      );
    }

    return EpgAgendaResponsiveBody(
      desktopChild: const EpgGrid(),
      compactChild: _EpgCompactAgendaBody(rows: rows),
    );
  }
}

/// Screen-owned adapter: only the compact branch subscribes to the Now tick.
class _EpgCompactAgendaBody extends ConsumerWidget {
  const _EpgCompactAgendaBody({required this.rows});

  final List<EpgGridRowData> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EpgCompactAgenda(
      rows: rows,
      now: ref.watch(epgGridNowMarkerProvider),
      onChannelTap: (channel) => activateEpgChannel(
        channel: channel,
        onSelectChannel: (channel) =>
            ref.read(selectedChannelProvider.notifier).state = channel,
        onOpenStream: (streamUrl) =>
            ref.read(playerNotifierProvider.notifier).openStream(streamUrl),
        onShowLiveTab: () =>
            ref.read(activeSidebarIndexProvider.notifier).state = 0,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EpgGridShimmer extends StatelessWidget {
  const _EpgGridShimmer({required this.rowCount});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppShimmer(
      baseColor: colorScheme.surfaceContainer,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        itemCount: rowCount,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: epgGridRowHeight,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
