import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_favorite_button.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/ui_logs_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_reminder_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/group_accent.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';
import 'package:shimmer/shimmer.dart';

/// Live channel list panel — consumes Drift watch streams via Riverpod.
/// Self-contained feature widget: no direct database or sync access.
class ChannelListPanel extends ConsumerWidget {
  const ChannelListPanel({super.key, this.headerActions});

  static const _headerInlineMinWidth = 720.0;

  /// Presentation-only actions reserved for the panel header.
  final Widget? headerActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _ensureDefaultPlaylistSelected(ref);
    _listenSyncErrors(context, ref);
    _listenEpgSyncFeedback(context, ref);
    _listenFavoriteErrors(context, ref);
    listenEpgReminderOrchestration(ref);

    final playlistsAsync = ref.watch(playlistsStreamProvider);
    final channelsAsync = ref.watch(liveChannelsStreamProvider);
    final liveChannels = channelsAsync.valueOrNull ?? const <Channel>[];
    final syncAsync = ref.watch(playlistSyncNotifierProvider);
    final epgSyncAsync = ref.watch(epgSyncNotifierProvider);
    final filteredChannels = ref.watch(filteredChannelsProvider);
    final searchQuery = ref.watch(globalSearchQueryProvider).trim();
    final totalLiveCount = liveChannels.length;
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    final showEpgReminder = watchEpgReminderVisible(ref);
    final reminderPlaylistId = ref.watch(epgUpdateReminderProvider);

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
                headerActions: headerActions,
              ),
              if (showEpgReminder && reminderPlaylistId != null) ...[
                const SizedBox(height: 12),
                _EpgUpdateReminderBanner(
                  isSyncing: epgSyncAsync.isLoading,
                  onUpdate: () => ref
                      .read(epgSyncNotifierProvider.notifier)
                      .sync(reminderPlaylistId),
                  onDismiss: () => dismissEpgReminder(ref, reminderPlaylistId),
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: channelsAsync.when(
                  loading: () => _buildLoadingList(context),
                  error: (err, _) => _buildMessage(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load channels',
                    subtitle: err.toString(),
                  ),
                  data: (_) {
                    if (selectedPlaylistId == null) {
                      return _buildMessage(
                        icon: Icons.playlist_play_rounded,
                        title: 'No playlist selected',
                        subtitle:
                            'Add and sync a playlist to see channels here.',
                      );
                    }
                    if (filteredChannels.isEmpty) {
                      return _buildMessage(
                        icon: Icons.tv_rounded,
                        title: searchQuery.isNotEmpty && totalLiveCount > 0
                            ? 'No channels match your search'
                            : 'No channels found',
                        subtitle: searchQuery.isNotEmpty && totalLiveCount > 0
                            ? 'Clear the search field to show all channels again.'
                            : 'Sync your playlist or try a different category filter.',
                      );
                    }
                    return _buildChannelList(context, ref, filteredChannels);
                  },
                ),
              ),
            ],
          ),
        );
      },
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
              message: 'Sync failed: $error',
              tone: AppStatusSnackBarTone.error,
            ),
          );
        },
      );
    });
  }

  void _listenEpgSyncFeedback(BuildContext context, WidgetRef ref) {
    ref.listen(epgSyncNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: 'EPG updated successfully.',
              tone: AppStatusSnackBarTone.success,
            ),
          );
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            appStatusSnackBar(
              context,
              message: 'EPG sync failed: $error',
              tone: AppStatusSnackBarTone.error,
            ),
          );
        },
      );
    });
  }

  void _listenFavoriteErrors(BuildContext context, WidgetRef ref) {
    ref.listen(channelFavoriteControllerProvider, (previous, next) {
      if (!next.hasError || previous?.error == next.error) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appStatusSnackBar(
          context,
          message: 'Favorit konnte nicht gespeichert werden.',
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
    Widget? headerActions,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
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
            '0 playlists',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          );
        }
        return Text(
          selectedPlaylistId == null
              ? 'No playlist selected'
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
      data: (playlists) => playlists.isEmpty
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
                'LIVE CHANNELS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 14),
              ),
            ),
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

        final boundedHeaderActions = headerActions == null
            ? null
            : SizedBox(
                width: constraints.maxWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: headerActions,
                ),
              );
        final regularPlaylistStatus = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: playlistStatus,
        );

        if (constraints.maxWidth < _headerInlineMinWidth) {
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
          channel.groupName ?? 'Uncategorized',
        );
        final isSelected = selectedChannel?.id == channel.id;

        return Padding(
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
                  isFavorite: channel.isFavorite,
                  isBusy: favoriteAction.isLoading,
                  onToggle: () => ref
                      .read(channelFavoriteControllerProvider.notifier)
                      .toggle(channel.id),
                ),
                const SizedBox(width: 4),
                M3LeadingSlot(
                  icon: Icons.chevron_right_rounded,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerLow,
      highlightColor: colorScheme.surfaceContainerHighest,
      enabled: !MediaQuery.disableAnimationsOf(context),
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

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _ChannelListMessage(icon: icon, title: title, subtitle: subtitle);
  }
}

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

class _ChannelEpgLine extends ConsumerWidget {
  const _ChannelEpgLine({required this.channelDbId});

  final int channelDbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final epgSyncAsync = ref.watch(epgSyncNotifierProvider);
    if (epgSyncAsync.isLoading) {
      return Text(
        'EPG wird geladen…',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
      );
    }

    final matchStatus = ref.watch(epgMatchStatusProvider(channelDbId));
    final programAsync = ref.watch(
      currentProgramForChannelProvider(channelDbId),
    );

    return programAsync.when(
      loading: () => Text(
        'EPG wird geladen…',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
      ),
      error: (_, _) => const _KeinEpgLabel(),
      data: (program) {
        if (matchStatus == EpgMatchStatus.matched && program != null) {
          return Text(
            'Jetzt: ${program.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          );
        }

        if (matchStatus == EpgMatchStatus.noTvgId ||
            matchStatus == EpgMatchStatus.noMatch) {
          return const _KeinEpgLabel();
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _KeinEpgLabel extends StatelessWidget {
  const _KeinEpgLabel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      'Kein EPG',
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
              'TV-Programm (EPG) wurde noch nicht aktualisiert.',
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
            label: Text(isSyncing ? 'Lädt…' : 'EPG jetzt aktualisieren'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Hinweis schließen',
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
      label: Text(isLoading ? 'Syncing…' : 'Sync'),
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
