import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/models/channel_catalog_load_state.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_sort_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_favorite_button.dart';
import 'package:m3uxtream_player/app/composition/channels/widgets/visible_live_channel_row.dart';
import 'package:m3uxtream_player/features/epg/providers/visible_live_channel_registry.dart';
import 'package:m3uxtream_player/core/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_reminder_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/app_shimmer.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Live channel list panel — consumes Drift watch streams via Riverpod.
/// Self-contained feature widget: no direct database or sync access.
class ChannelListPanel extends ConsumerStatefulWidget {
  const ChannelListPanel({super.key, this.headerActions});

  static const _headerInlineMinWidth = 720.0;

  /// Presentation-only actions reserved for the panel header.
  final Widget? headerActions;

  @override
  ConsumerState<ChannelListPanel> createState() => _ChannelListPanelState();
}

class _ChannelListPanelState extends ConsumerState<ChannelListPanel> {
  Timer? _slowTimer;
  Timer? _retryTimer;
  bool _slowElapsed = false;
  bool _retryElapsed = false;
  List<Channel>? _lastRows;
  PlaylistCatalogScope? _lastRowsScope;
  PlaylistCatalogScope? _observedScope;

  @override
  void dispose() {
    _slowTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureDefaultPlaylistSelected(ref);
    _listenSyncErrors(context, ref);
    _listenEpgSyncFeedback(context, ref);
    listenEpgReminderOrchestration(ref);

    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final channelsAsync = ref.watch(liveChannelsStreamProvider);
    final liveChannels = channelsAsync.valueOrNull ?? const <Channel>[];
    if (liveChannels.isNotEmpty) {
      _listenFavoriteErrors(context, ref);
    }
    final syncAsync = ref.watch(playlistSyncNotifierProvider);
    final sortedChannelsAsync = ref.watch(sortedFilteredChannelsProvider);
    final immediateFilteredChannels = ref.watch(filteredChannelsProvider);
    final searchQuery = ref.watch(globalSearchQueryProvider).trim();
    final totalLiveCount = liveChannels.length;
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
    final catalogPlaylistIds = ref.watch(
      playlistCatalogPlaylistIdsProvider(scope),
    );
    final scopeChanged = _observedScope != null && _observedScope != scope;
    _observedScope = scope;
    if (scopeChanged) {
      _lastRows = null;
      _lastRowsScope = null;
    }
    final epgJobs = ref.watch(epgSyncJobsProvider).valueOrNull ?? const {};
    final selectedEpgJob = selectedPlaylistId == null
        ? null
        : epgJobs[selectedPlaylistId];
    final showEpgReminder = watchEpgReminderVisible(ref);
    final reminderPlaylistId = ref.watch(epgUpdateReminderProvider);

    final rawSortedValue = sortedChannelsAsync.valueOrNull;
    final sortedValue =
        !scopeChanged &&
            !channelsAsync.isLoading &&
            _rowsBelongToScope(rawSortedValue, scope, catalogPlaylistIds)
        ? rawSortedValue
        : null;
    final preserveRowsAcrossCatalogTransition =
        _lastRowsScope == scope &&
        _lastRows?.isNotEmpty == true &&
        sortedValue?.isEmpty == true &&
        (channelsAsync.isLoading || channelsAsync.hasError);
    if (sortedChannelsAsync.hasValue && !preserveRowsAcrossCatalogTransition) {
      if (sortedValue != null) {
        _lastRows = sortedValue;
        _lastRowsScope = scope;
      }
    }
    final immediateRows =
        !scopeChanged &&
            !channelsAsync.isLoading &&
            _rowsBelongToScope(
              immediateFilteredChannels,
              scope,
              catalogPlaylistIds,
            )
        ? immediateFilteredChannels
        : const <Channel>[];
    final displayedChannels =
        (preserveRowsAcrossCatalogTransition ? null : sortedValue) ??
        (_lastRowsScope == scope ? _lastRows : null) ??
        immediateRows;
    final hasRows = displayedChannels.isNotEmpty;
    final isLoading = channelsAsync.isLoading || sortedChannelsAsync.isLoading;
    final hasError = channelsAsync.hasError || sortedChannelsAsync.hasError;
    _syncInitialLoadingTimers(isLoading && !hasRows && !hasError);
    final loadState = resolveChannelCatalogLoadState(
      hasRows: hasRows,
      isLoading: isLoading,
      hasError: hasError,
      slowElapsed: _slowElapsed,
    );
    final hasCatalogContext = scope.isAllActive
        ? catalogPlaylistIds.isNotEmpty
        : scope.playlistId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return AppSurface(
          level: AppSurfaceLevel.low,
          elevation: AppElevation.level1,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                context,
                ref,
                playlistsAsync,
                selectedPlaylistId,
                syncAsync,
                enableSort: hasRows,
                showCatalogProgress:
                    loadState == ChannelCatalogLoadState.refreshing,
                headerActions: widget.headerActions,
              ),
              if (loadState == ChannelCatalogLoadState.errorWithData) ...[
                const SizedBox(height: 8),
                _ChannelCatalogNotice(
                  icon: Icons.warning_amber_rounded,
                  message: context.l10n.channelRefreshFailedRetained,
                ),
              ],
              if (showEpgReminder && reminderPlaylistId != null) ...[
                const SizedBox(height: 12),
                _EpgUpdateReminderBanner(
                  isSyncing: selectedEpgJob?.isActive ?? false,
                  onUpdate: () => unawaited(
                    ref
                        .read(epgSyncControllerProvider)
                        .enqueue(reminderPlaylistId)
                        .catchError((_) {}),
                  ),
                  onDismiss: () => dismissEpgReminder(ref, reminderPlaylistId),
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: !hasRows && hasError
                    ? _buildMessage(
                        icon: Icons.error_outline_rounded,
                        title: context.l10n.channelLoadFailed,
                        subtitle:
                            (sortedChannelsAsync.error ?? channelsAsync.error)
                                .toString(),
                      )
                    : !hasRows && isLoading
                    ? _buildInitialLoading(
                        context,
                        showSlowMessage: _slowElapsed,
                        showRetry: _retryElapsed,
                        onRetry: _retryCatalog,
                      )
                    : !hasCatalogContext
                    ? _buildMessage(
                        icon: Icons.playlist_play_rounded,
                        title: context.l10n.favoritesNoPlaylistTitle,
                        subtitle: context.l10n.channelNoPlaylistSubtitle,
                      )
                    : displayedChannels.isEmpty
                    ? _buildMessage(
                        icon: Icons.tv_rounded,
                        title: searchQuery.isNotEmpty && totalLiveCount > 0
                            ? context.l10n.channelNoSearchResults
                            : context.l10n.channelNoChannelsFound,
                        subtitle: searchQuery.isNotEmpty && totalLiveCount > 0
                            ? context.l10n.channelClearSearchSubtitle
                            : context.l10n.channelSyncOrFilterSubtitle,
                      )
                    : _buildChannelList(context, ref, scope, displayedChannels),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _rowsBelongToScope(
    List<Channel>? rows,
    PlaylistCatalogScope scope,
    Iterable<int> catalogPlaylistIds,
  ) {
    if (rows == null) return false;
    if (scope.isAllActive) {
      return rows.every(
        (channel) => catalogPlaylistIds.contains(channel.playlistId),
      );
    }
    final playlistId = scope.playlistId;
    return playlistId != null &&
        rows.every((channel) => channel.playlistId == playlistId);
  }

  void _syncInitialLoadingTimers(bool waitingForFirstRows) {
    if (!waitingForFirstRows) {
      _slowTimer?.cancel();
      _retryTimer?.cancel();
      _slowTimer = null;
      _retryTimer = null;
      _slowElapsed = false;
      _retryElapsed = false;
      return;
    }
    _slowTimer ??= Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _slowElapsed = true);
    });
    _retryTimer ??= Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _retryElapsed = true);
    });
  }

  void _retryCatalog() {
    _slowTimer?.cancel();
    _retryTimer?.cancel();
    _slowTimer = null;
    _retryTimer = null;
    setState(() {
      _slowElapsed = false;
      _retryElapsed = false;
    });
    final scope = ref.read(effectivePlaylistCatalogScopeProvider);
    ref.invalidate(
      playlistCatalogStreamProvider(
        PlaylistCatalogQuery(
          scope: scope,
          mediaType: PlaylistCatalogMediaType.live,
        ),
      ),
    );
  }

  void _ensureDefaultPlaylistSelected(WidgetRef ref) {
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

  void _listenSyncErrors(BuildContext context, WidgetRef ref) {
    ref.listen(playlistSyncNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: context.l10n.channelSyncFailed(error.toString()),
              tone: AppStatusSnackBarTone.error,
            ),
          );
        },
      );
    });
  }

  void _listenEpgSyncFeedback(BuildContext context, WidgetRef ref) {
    ref.listen(epgSyncEventsProvider, (previous, next) {
      final job = next.valueOrNull;
      if (job == null || job.origin != EpgSyncOrigin.manual) return;
      if (job.status == EpgSyncStatus.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          appStatusSnackBar(
            context,
            message: context.l10n.channelEpgUpdated,
            tone: AppStatusSnackBarTone.success,
          ),
        );
      } else if (job.status == EpgSyncStatus.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          appStatusSnackBar(
            context,
            message: context.l10n.channelEpgSyncFailed('${job.error}'),
            tone: AppStatusSnackBarTone.error,
          ),
        );
      }
    });
  }

  void _listenFavoriteErrors(BuildContext context, WidgetRef ref) {
    ref.listen(channelFavoriteControllerProvider, (previous, next) {
      if (!next.hasError || previous?.error == next.error) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appStatusSnackBar(
          context,
          message: context.l10n.favoriteSaveFailed,
          tone: AppStatusSnackBarTone.error,
        ),
      );
    });
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Playlist>> playlistsAsync,
    int? selectedPlaylistId,
    AsyncValue<void> syncAsync, {
    required bool enableSort,
    required bool showCatalogProgress,
    Widget? headerActions,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final scope = ref.watch(effectivePlaylistCatalogScopeProvider);
    final playlistStatus = playlistsAsync.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) =>
          Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
      data: (playlists) {
        if (playlists.isEmpty) {
          return Text(
            context.l10n.channelPlaylistCount(0),
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          );
        }
        return Text(
          scope.isAllActive
              ? context.l10n.channelAllActivePlaylists
              : selectedPlaylistId == null
              ? context.l10n.favoritesNoPlaylistTitle
              : playlists
                    .firstWhere(
                      (p) => p.id == selectedPlaylistId,
                      orElse: () => playlists.first,
                    )
                    .name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );

    final syncButton = playlistsAsync.maybeWhen(
      data: (playlists) => playlists.isEmpty || scope.isAllActive
          ? null
          : _SyncButton(
              isLoading: syncAsync.isLoading,
              enabled: selectedPlaylistId != null && !syncAsync.isLoading,
              onPressed: () {
                if (selectedPlaylistId != null) {
                  ref
                      .read(playlistSyncNotifierProvider.notifier)
                      .sync(selectedPlaylistId);
                }
              },
            ),
      orElse: () => null,
    );
    final sortButton = !enableSort
        ? null
        : scope.isAllActive
        ? _ChannelSortMenu(
            mode: ref.watch(allActiveChannelSortModeProvider),
            onChanged: (mode) => ref
                .read(allActiveChannelSortModeProvider.notifier)
                .setMode(mode),
          )
        : selectedPlaylistId == null
        ? null
        : _ChannelSortMenu(
            mode: ref.watch(channelSortModeProvider(selectedPlaylistId)),
            onChanged: (mode) => ref
                .read(channelSortModeProvider(selectedPlaylistId).notifier)
                .setMode(mode),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Row(
          children: [
            Icon(
              Icons.playlist_play_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.channelLiveTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 14),
              ),
            ),
            if (showCatalogProgress) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        );

        final boundedPlaylistStatus = SizedBox(
          width: constraints.maxWidth,
          child: Row(
            children: [
              Expanded(child: playlistStatus),
              if (syncButton != null) ...[const SizedBox(width: 8), syncButton],
            ],
          ),
        );

        final boundedHeaderActions = headerActions == null && sortButton == null
            ? null
            : SizedBox(
                width: constraints.maxWidth,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [?sortButton, ?headerActions],
                ),
              );
        final regularPlaylistStatus = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: playlistStatus,
        );

        if (constraints.maxWidth < ChannelListPanel._headerInlineMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: constraints.maxWidth, child: title),
              const SizedBox(height: 8),
              boundedPlaylistStatus,
              if (boundedHeaderActions != null) ...[
                const SizedBox(height: 4),
                boundedHeaderActions,
              ],
            ],
          );
        }

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            regularPlaylistStatus,
            ?syncButton,
            ?sortButton,
            if (headerActions != null) ...[
              const SizedBox(width: 4),
              headerActions,
            ],
          ],
        );

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            Flexible(
              child: Align(alignment: Alignment.centerRight, child: actions),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChannelList(
    BuildContext context,
    WidgetRef ref,
    PlaylistCatalogScope scope,
    List<Channel> channels,
  ) {
    final selectedChannel = ref.watch(selectedChannelProvider);
    final favoriteAction = ref.watch(channelFavoriteControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final accent = GroupAccent.forGroup(
          channel.groupName ?? context.l10n.channelUncategorized,
        );
        final isSelected = selectedChannel?.id == channel.id;

        return VisibleLiveChannelRow(
          key: ValueKey((scope, channel.id)),
          candidate: VisibleLiveChannelCandidate(
            channelId: channel.id,
            playlistId: channel.playlistId,
            name: channel.name,
            tvgId: channel.tvgId,
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: M3MediaListItem(
              title: channel.name,
              leading: _ChannelLogo(logoUrl: channel.logo, accent: accent),
              subtitle: _ChannelEpgLine(channelDbId: channel.id),
              selected: isSelected,
              surfaceLevel: AppSurfaceLevel.base,
              surfaceColor: Colors.transparent,
              onActivate: () {
                ref.read(selectedChannelProvider.notifier).state = channel;
                ref
                    .read(playerNotifierProvider.notifier)
                    .openStream(channel.streamUrl);
                ref
                    .read(uiLogsProvider.notifier)
                    .addLog('UI: Selected channel "${channel.name}"');
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChannelFavoriteButton(
                    channelId: channel.id,
                    isFavorite: favoriteAction.isFavorite(channel),
                    isBusy: favoriteAction.isBusy(channel.id),
                    onToggle: () => ref
                        .read(channelFavoriteControllerProvider.notifier)
                        .toggle(
                          channel.id,
                          currentFavorite: favoriteAction.isFavorite(channel),
                        ),
                  ),
                  const SizedBox(width: 4),
                  M3LeadingSlot(
                    icon: Icons.chevron_right_rounded,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppShimmer(
      baseColor: colorScheme.surfaceContainerLow,
      highlightColor: colorScheme.surfaceContainerHighest,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoading(
    BuildContext context, {
    required bool showSlowMessage,
    required bool showRetry,
    required VoidCallback onRetry,
  }) {
    return Column(
      children: [
        if (showSlowMessage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.channelLoading,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (showRetry) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        Expanded(child: _buildLoadingList(context)),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _ChannelListMessage(icon: icon, title: title, subtitle: subtitle);
  }
}

class _ChannelSortMenu extends StatelessWidget {
  const _ChannelSortMenu({required this.mode, required this.onChanged});

  final ChannelSortMode mode;
  final ValueChanged<ChannelSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: false,
      menuChildren: [
        for (final option in ChannelSortMode.values)
          MenuItemButton(
            leadingIcon: Icon(
              option == mode ? Icons.check_rounded : Icons.sort_rounded,
            ),
            onPressed: () => onChanged(option),
            child: Text(_channelSortModeLabel(context, option)),
          ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          key: const ValueKey('channel-sort-menu'),
          tooltip: context.l10n.channelSortTooltip(
            _channelSortModeLabel(context, mode),
          ),
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.sort_rounded),
        );
      },
    );
  }
}

String _channelSortModeLabel(BuildContext context, ChannelSortMode mode) =>
    switch (mode) {
      ChannelSortMode.providerDefault => context.l10n.channelSortProvider,
      ChannelSortMode.alphabetical => context.l10n.channelSortAlphabetical,
      ChannelSortMode.numeric => context.l10n.channelSortNumber,
    };

/// Responsive empty/error/info presentation for the channel list.
///
/// The panel can become very short in compact Live mode after the player has
/// received its aspect-ratio slot. Keep the message centered when it fits and
/// allow the complete, untruncated text to scroll when it does not.
class _ChannelListMessage extends StatelessWidget {
  const _ChannelListMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0.0;

        return SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 32, color: colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChannelCatalogNotice extends StatelessWidget {
  const _ChannelCatalogNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelEpgLine extends ConsumerWidget {
  const _ChannelEpgLine({required this.channelDbId});

  final int channelDbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final matches = ref.watch(visibleLiveEpgMatchesProvider);
    final programs = ref.watch(currentProgramsForVisibleChannelsProvider);

    final match = matches.valueOrNull?[channelDbId];
    final program = programs.valueOrNull?[channelDbId];

    // While the registry, the bounded match or the bulk query is still
    // working, the row stays fully visible with a neutral loading state.
    // An EPG error never moves the channel list into loading or error.
    final isWaitingForMatch =
        (matches.isLoading && !matches.hasValue) || match == null;
    final isWaitingForProgram =
        match?.matchStatus == EpgMatchStatus.matched &&
        programs.isLoading &&
        !programs.hasValue;

    if (!isWaitingForProgram &&
        match?.matchStatus == EpgMatchStatus.matched &&
        program != null) {
      return Text(
        context.l10n.channelEpgNow(program.title),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
      );
    }

    if (isWaitingForMatch || isWaitingForProgram) {
      return Text(
        context.l10n.channelEpgLoading,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
      );
    }

    return const _KeinEpgLabel();
  }
}

class _KeinEpgLabel extends StatelessWidget {
  const _KeinEpgLabel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      context.l10n.channelNoEpg,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _EpgUpdateReminderBanner extends StatelessWidget {
  const _EpgUpdateReminderBanner({
    required this.isSyncing,
    required this.onUpdate,
    required this.onDismiss,
  });

  final bool isSyncing;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 18,
            color: colorScheme.onSecondaryContainer,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              context.l10n.channelEpgNotUpdated,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: isSyncing ? null : onUpdate,
            icon: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              isSyncing
                  ? context.l10n.channelEpgUpdating
                  : context.l10n.channelEpgUpdateNow,
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
            tooltip: context.l10n.commonDismissTooltip,
          ),
        ],
      ),
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: enabled && !isLoading ? onPressed : null,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded),
      label: Text(
        isLoading ? context.l10n.commonSyncing : context.l10n.commonSync,
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.logoUrl, required this.accent});

  final String? logoUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const size = 36.0;
    final cacheSize = _cachePixels(
      size,
      MediaQuery.devicePixelRatioOf(context),
    );

    if (logoUrl == null || logoUrl!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Icon(
          Icons.tv_rounded,
          size: 16,
          color: accent.withValues(alpha: 0.8),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        width: size,
        height: size,
        imageUrl: logoUrl!,
        fit: BoxFit.cover,
        memCacheWidth: cacheSize,
        memCacheHeight: cacheSize,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: colorScheme.surfaceContainer,
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: accent.withValues(alpha: 0.15),
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 14,
            color: accent.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

int _cachePixels(double logicalSize, double dpr) {
  return (logicalSize * dpr).ceil().clamp(1, 4096);
}
