import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_compact_agenda.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_grid.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen_layout.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_toolbar.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:shimmer/shimmer.dart';

/// EPG guide screen — sidebar index 2.
class EpgScreen extends ConsumerWidget {
  const EpgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final epgSyncAsync = ref.watch(epgSyncNotifierProvider);
    final entriesAsync = ref.watch(epgGridEntriesStreamProvider);
    final catalogAsync = ref.watch(knownEpgChannelIdsProvider);
    final rows = ref.watch(epgGridRowsProvider);
    final channels = ref.watch(epgGridChannelsProvider);
    final searchQuery = ref.watch(globalSearchQueryProvider).trim();
    final totalLiveCount =
        ref.watch(liveChannelsStreamProvider).valueOrNull?.length ?? 0;
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    final playlists =
        ref.watch(playlistsStreamProvider).valueOrNull ?? const [];

    Playlist? activePlaylist;
    if (selectedPlaylistId != null) {
      for (final p in playlists) {
        if (p.id == selectedPlaylistId) {
          activePlaylist = p;
          break;
        }
      }
    }

    final hasEpgUrl = activePlaylist?.epgUrl?.trim().isNotEmpty ?? false;
    final hasVisibleProgrammes = epgGridHasVisibleProgrammes(rows);
    final hasMatchedChannels = epgGridHasMatchedChannels(rows);
    final isManualSync = epgSyncAsync.isLoading;
    final isInitialCatalogLoad =
        catalogAsync.isLoading && !catalogAsync.hasValue;
    final isEntriesLoading = entriesAsync.isLoading && !entriesAsync.hasValue;

    return AppSurface(
      key: const ValueKey('epg-screen-surface'),
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(20),
      child: EpgScreenLayout(
        toolbar: EpgToolbar(
          isBusy: isManualSync,
          isEntriesLoading: isEntriesLoading,
          onJumpToNow: () => jumpEpgWindowToNow(ref),
          onBackTwoHours: () => shiftEpgWindow(ref, const Duration(hours: -2)),
          onForwardTwoHours: () =>
              shiftEpgWindow(ref, const Duration(hours: 2)),
          onBackOneDay: () => shiftEpgWindow(ref, const Duration(days: -1)),
          onForwardOneDay: () => shiftEpgWindow(ref, const Duration(days: 1)),
          onZoomOut: () => adjustEpgGridPixelsPerMinute(ref, -0.25),
          onZoomIn: () => adjustEpgGridPixelsPerMinute(ref, 0.25),
          onResetZoom: () =>
              setEpgGridPixelsPerMinute(ref, epgGridPixelsPerMinuteDefault),
        ),
        body: _buildBody(
          context,
          ref,
          isInitialCatalogLoad: isInitialCatalogLoad,
          isManualSync: isManualSync,
          isEntriesLoading: isEntriesLoading,
          channelsEmpty: channels.isEmpty,
          searchQuery: searchQuery,
          totalLiveCount: totalLiveCount,
          hasVisibleProgrammes: hasVisibleProgrammes,
          hasMatchedChannels: hasMatchedChannels,
          hasEpgUrl: hasEpgUrl,
          selectedPlaylistId: selectedPlaylistId,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref, {
    required bool isInitialCatalogLoad,
    required bool isManualSync,
    required bool isEntriesLoading,
    required bool channelsEmpty,
    required String searchQuery,
    required int totalLiveCount,
    required bool hasVisibleProgrammes,
    required bool hasMatchedChannels,
    required bool hasEpgUrl,
    required int? selectedPlaylistId,
    required List<EpgGridRowData> rows,
  }) {
    if (channelsEmpty) {
      if (searchQuery.isNotEmpty && totalLiveCount > 0) {
        return _EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No channels match your search',
          subtitle:
              'Clear the search field to show all $totalLiveCount channels again.',
        );
      }
      return const _EmptyState(
        icon: Icons.playlist_play_rounded,
        title: 'No channels loaded',
        subtitle:
            'Select a playlist and sync channels on the Live tab or in Settings.',
      );
    }

    if (isInitialCatalogLoad) {
      return _EpgGridShimmer(rowCount: rows.length.clamp(4, 10));
    }

    if (isManualSync) {
      return _EpgGridShimmer(rowCount: rows.length.clamp(4, 10));
    }

    if (!hasVisibleProgrammes &&
        !hasMatchedChannels &&
        !isEntriesLoading &&
        rows.isNotEmpty) {
      return _EmptyState(
        icon: Icons.calendar_month_rounded,
        title: 'No EPG data for this time window',
        subtitle: hasEpgUrl
            ? 'Update the TV programme guide for your active playlist.'
            : 'Configure an EPG URL in Settings or sync an M3U with url-tvg header.',
        actionLabel: hasEpgUrl && selectedPlaylistId != null
            ? 'EPG aktualisieren'
            : null,
        onAction: hasEpgUrl && selectedPlaylistId != null
            ? () => ref
                  .read(epgSyncNotifierProvider.notifier)
                  .sync(selectedPlaylistId)
            : null,
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
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
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainer,
      highlightColor: colorScheme.surfaceContainerHighest,
      enabled: !MediaQuery.disableAnimationsOf(context),
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
