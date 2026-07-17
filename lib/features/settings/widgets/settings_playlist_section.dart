import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_status_pill.dart';
import 'package:m3uxtream_player/shared/widgets/m3_settings_section_header.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:shimmer/shimmer.dart';

class SettingsPlaylistItem {
  const SettingsPlaylistItem({
    required this.name,
    required this.type,
    required this.isActive,
    required this.lastSyncedAt,
    required this.epgUrl,
    required this.epgLastSyncedAt,
    required this.onSync,
    required this.onEpgSync,
    required this.onEdit,
    required this.onActiveChanged,
    required this.onDelete,
  });

  final String name;
  final String type;
  final bool isActive;
  final DateTime? lastSyncedAt;
  final String? epgUrl;
  final DateTime? epgLastSyncedAt;
  final VoidCallback onSync;
  final VoidCallback onEpgSync;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onDelete;
}

class SettingsPlaylistSection extends StatelessWidget {
  const SettingsPlaylistSection({
    required this.items,
    required this.isLoading,
    required this.errorMessage,
    required this.isSyncing,
    required this.isEpgSyncing,
    required this.isBusy,
    required this.compact,
    super.key,
  });

  final List<SettingsPlaylistItem>? items;
  final bool isLoading;
  final String? errorMessage;
  final bool isSyncing;
  final bool isEpgSyncing;
  final bool isBusy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.standard,
      padding: EdgeInsets.all(compact ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaylistSectionHeader(compact: compact),
          SizedBox(height: compact ? 12 : 16),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (errorMessage case final message?) {
      return Center(
        child: _PlaylistLoadError(message: message, compact: compact),
      );
    }
    if (items == null || items!.isEmpty) {
      return Center(child: _EmptyPlaylistState(compact: compact));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => SettingsPlaylistTile(
        item: items![index],
        isSyncing: isSyncing,
        isEpgSyncing: isEpgSyncing,
        isBusy: isBusy,
      ),
    );
  }
}

class _PlaylistSectionHeader extends StatelessWidget {
  const _PlaylistSectionHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return M3SettingsSectionHeader(
      icon: Icons.playlist_play_rounded,
      iconColor: Theme.of(context).colorScheme.secondary,
      title: 'SAVED PLAYLISTS',
      description:
          'Sync, refresh EPG, or remove a playlist without changing the flow around it.',
      compact: compact,
    );
  }
}

class _PlaylistLoadError extends StatelessWidget {
  const _PlaylistLoadError({required this.message, required this.compact});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.low,
      surfaceColor: colors.errorContainer.withValues(alpha: 0.5),
      padding: EdgeInsets.all(compact ? 16 : 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.error.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: colors.error,
            size: compact ? 22 : 24,
          ),
          const SizedBox(height: 10),
          Text(
            'Failed to load playlists',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaylistState extends StatelessWidget {
  const _EmptyPlaylistState({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: EdgeInsets.all(compact ? 20 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: compact ? 32 : 36,
            color: colors.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No playlists yet',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: compact ? 13.5 : 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add an M3U or Xtream playlist to get started.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class SettingsPlaylistTile extends StatelessWidget {
  const SettingsPlaylistTile({
    required this.item,
    required this.isSyncing,
    required this.isEpgSyncing,
    required this.isBusy,
    super.key,
  });

  final SettingsPlaylistItem item;
  final bool isSyncing;
  final bool isEpgSyncing;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typeColor = item.type == 'xtream' ? colors.secondary : colors.primary;
    final stateColor = item.isActive
        ? colors.secondary
        : colors.onSurfaceVariant;
    final lastSynced = item.lastSyncedAt != null
        ? _formatDateTime(item.lastSyncedAt!.toLocal())
        : 'Never synced';
    final epgLastSynced = item.epgLastSyncedAt != null
        ? _formatRelativeTime(item.epgLastSyncedAt!.toLocal())
        : 'EPG never synced';
    final epgUrl = item.epgUrl;
    final hasEpgUrl = epgUrl != null && epgUrl.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions = constraints.maxWidth < 560;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                M3StatusPill(label: item.type.toUpperCase(), accent: typeColor),
                M3StatusPill(
                  label: item.isActive ? 'Active' : 'Inactive',
                  accent: stateColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Playlist: $lastSynced',
              style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
            ),
          ],
        );
        final actions = _PlaylistActions(
          item: item,
          isSyncing: isSyncing,
          isEpgSyncing: isEpgSyncing,
          isBusy: isBusy,
          hasEpgUrl: hasEpgUrl,
          showSyncLabel: constraints.maxWidth >= 360,
        );

        return AppSurface(
          level: AppSurfaceLevel.low,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stackActions) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaylistTypeIcon(type: item.type, color: typeColor),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actions),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlaylistTypeIcon(type: item.type, color: typeColor),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
              const SizedBox(height: 10),
              if (hasEpgUrl) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        epgUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ] else if (item.type == 'm3u')
                Text(
                  'EPG URL: not found in M3U header',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                Text(
                  'EPG URL: not configured',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      epgLastSynced,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlaylistActions extends StatelessWidget {
  const _PlaylistActions({
    required this.item,
    required this.isSyncing,
    required this.isEpgSyncing,
    required this.isBusy,
    required this.hasEpgUrl,
    required this.showSyncLabel,
  });

  final SettingsPlaylistItem item;
  final bool isSyncing;
  final bool isEpgSyncing;
  final bool isBusy;
  final bool hasEpgUrl;
  final bool showSyncLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: item.isActive ? 'Deactivate playlist' : 'Activate playlist',
          child: Switch(
            value: item.isActive,
            onChanged: isBusy ? null : item.onActiveChanged,
          ),
        ),
        const SizedBox(width: 6),
        _SyncButton(
          isLoading: isSyncing,
          enabled: !isBusy,
          onPressed: item.onSync,
          showLabel: showSyncLabel,
        ),
        _PlaylistOverflowMenu(
          item: item,
          isBusy: isBusy,
          isEpgSyncing: isEpgSyncing,
          hasEpgUrl: hasEpgUrl,
        ),
      ],
    );
  }
}

class _PlaylistOverflowMenu extends StatelessWidget {
  const _PlaylistOverflowMenu({
    required this.item,
    required this.isBusy,
    required this.isEpgSyncing,
    required this.hasEpgUrl,
  });

  final SettingsPlaylistItem item;
  final bool isBusy;
  final bool isEpgSyncing;
  final bool hasEpgUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: 48,
      child: PopupMenuButton<void>(
        tooltip: 'More playlist actions',
        itemBuilder: (context) => [
          PopupMenuItem<void>(
            enabled: !isBusy,
            onTap: isBusy ? null : item.onEdit,
            child: const Text('Edit playlist'),
          ),
          PopupMenuItem<void>(
            enabled: !isBusy && hasEpgUrl,
            onTap: !isBusy && hasEpgUrl ? item.onEpgSync : null,
            child: Text(isEpgSyncing ? 'EPG…' : 'EPG aktualisieren'),
          ),
          PopupMenuItem<void>(
            enabled: !isBusy,
            onTap: isBusy ? null : item.onDelete,
            child: const Text('Delete playlist'),
          ),
        ],
        icon: Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: colors.onSurfaceVariant.withValues(alpha: isBusy ? 0.3 : 0.72),
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class _PlaylistTypeIcon extends StatelessWidget {
  const _PlaylistTypeIcon({required this.type, required this.color});

  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.low,
      width: 36,
      height: 36,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Icon(
        type == 'xtream' ? Icons.dns_rounded : Icons.link_rounded,
        size: 16,
        color: color,
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d.$m.${dt.year} $h:$min';
}

String _formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'EPG: just now';
  if (diff.inHours < 1) return 'EPG: ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'EPG: ${diff.inHours} h ago';
  if (diff.inDays < 7) return 'EPG: ${diff.inDays} d ago';
  return 'EPG: ${_formatDateTime(dt)}';
}

class _SyncButton extends StatelessWidget {
  const _SyncButton({
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
    required this.showLabel,
  });

  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final button = showLabel
        ? OutlinedButton.icon(
            onPressed: isLoading || !enabled ? null : onPressed,
            icon: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : const Icon(Icons.sync_rounded, size: 16),
            label: Text(isLoading ? 'Syncing…' : 'Sync'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        : M3ActionSlot(
            icon: isLoading ? null : Icons.sync_rounded,
            tooltip: 'Sync',
            semanticLabel: 'Sync',
            onPressed: isLoading || !enabled ? null : onPressed,
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : null,
          );
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: colors.primary.withValues(alpha: 0.15),
        highlightColor: colors.secondary.withValues(alpha: 0.45),
        period: const Duration(milliseconds: 1100),
        enabled: !MediaQuery.disableAnimationsOf(context),
        child: button,
      );
    }
    return button;
  }
}
