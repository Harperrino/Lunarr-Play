import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/vod_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_card.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/playback_prep_panel.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_grid.dart';
import 'package:m3uxtream_player/shared/theme/catalogue_surface_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/category_sidebar.dart';
import 'package:m3uxtream_player/shared/widgets/tonal_toolbar_button.dart';
import 'package:shimmer/shimmer.dart';

/// VOD movies screen — sidebar index 3.
class VodScreen extends ConsumerWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vodAsync = ref.watch(vodChannelsStreamProvider);
    final movies = ref.watch(vodChannelsProvider);
    final totalMovies = vodAsync.valueOrNull?.length ?? 0;
    final searchQuery = ref.watch(globalSearchQueryProvider).trim();
    final groups = ref.watch(vodGroupsProvider);
    final selectedGroup = ref.watch(selectedVodGroupFilterProvider);
    final pinnedGroups =
        ref.watch(pinnedGroupsProvider).valueOrNull ?? const <String>[];
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    final syncAsync = ref.watch(playlistSyncNotifierProvider);
    final prepTarget = ref.watch(playbackPrepTargetProvider);

    return AppSurface(
      key: const ValueKey('vod-screen-surface'),
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VodToolbar(
            movieCount: movies.length,
            isSyncing: syncAsync.isLoading,
            onSync: selectedPlaylistId != null
                ? () => ref
                      .read(playlistSyncNotifierProvider.notifier)
                      .sync(selectedPlaylistId)
                : null,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: prepTarget != null && !prepTarget.isSeries
                ? PlaybackPrepPanel(target: prepTarget)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: vodAsync.when(
                          loading: () => const _VodGridShimmer(),
                          error: (err, _) => _VodEmptyState(
                            icon: Icons.error_outline_rounded,
                            title: 'Failed to load movies',
                            subtitle: err.toString(),
                          ),
                          data: (_) {
                            if (selectedPlaylistId == null) {
                              return const _VodEmptyState(
                                icon: Icons.playlist_play_rounded,
                                title: 'No playlist selected',
                                subtitle:
                                    'Select a playlist in the Playlists tab or Settings.',
                              );
                            }
                            if (movies.isEmpty) {
                              final searchActive =
                                  searchQuery.isNotEmpty && totalMovies > 0;
                              final filteredEmpty = totalMovies > 0;
                              final localFiltersActive =
                                  searchQuery.isNotEmpty ||
                                  selectedGroup != kAllGroupsFilter;
                              return _VodEmptyState(
                                icon: searchActive
                                    ? Icons.search_off_rounded
                                    : Icons.movie_rounded,
                                title: searchActive
                                    ? 'No movies match your search'
                                    : filteredEmpty
                                    ? 'No movies visible'
                                    : 'No movies found',
                                subtitle: searchActive
                                    ? 'Clear the search field to show all movies again.'
                                    : filteredEmpty
                                    ? 'Your VOD catalogue is loaded, but filters or hidden categories are hiding the visible list.'
                                    : syncAsync.isLoading
                                    ? 'Syncing playlist…'
                                    : 'Sync your Xtream playlist to load VOD movies.',
                                actionLabel: filteredEmpty && localFiltersActive
                                    ? 'Filter zurücksetzen'
                                    : searchActive ||
                                          syncAsync.isLoading ||
                                          filteredEmpty
                                    ? null
                                    : 'Playlist syncen',
                                onAction: filteredEmpty && localFiltersActive
                                    ? () {
                                        ref
                                                .read(
                                                  globalSearchQueryProvider
                                                      .notifier,
                                                )
                                                .state =
                                            '';
                                        ref
                                                .read(
                                                  selectedVodGroupFilterProvider
                                                      .notifier,
                                                )
                                                .state =
                                            kAllGroupsFilter;
                                      }
                                    : searchActive ||
                                          syncAsync.isLoading ||
                                          filteredEmpty
                                    ? null
                                    : () => ref
                                          .read(
                                            playlistSyncNotifierProvider
                                                .notifier,
                                          )
                                          .sync(selectedPlaylistId),
                              );
                            }
                            return VodGrid(channels: movies);
                          },
                        ),
                      ),
                      if (groups.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        CategorySidebar(
                          groups: groups,
                          selectedGroup: selectedGroup,
                          onSelected: (group) =>
                              ref
                                      .read(
                                        selectedVodGroupFilterProvider.notifier,
                                      )
                                      .state =
                                  group,
                          pinnedGroups: pinnedGroups,
                          title: 'Genres',
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _VodToolbar extends StatelessWidget {
  const _VodToolbar({
    required this.movieCount,
    required this.isSyncing,
    this.onSync,
  });

  final int movieCount;
  final bool isSyncing;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.movie_rounded, color: colors.primary, size: 20),
        const SizedBox(width: 10),
        Text(
          'VOD MOVIES',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 14),
        ),
        const SizedBox(width: 10),
        Text(
          '$movieCount',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
        ),
        if (isSyncing) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        if (onSync != null)
          TonalToolbarButton(
            label: 'Sync',
            icon: Icons.sync_rounded,
            onPressed: isSyncing ? null : onSync,
          ),
      ],
    );
  }
}

class _VodEmptyState extends StatelessWidget {
  const _VodEmptyState({
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
    final colors = Theme.of(context).colorScheme;
    final roles = CatalogueSurfaceRoles.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AppSurface(
          level: AppSurfaceLevel.standard,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: roles.iconContainerStart,
                  border: Border.all(color: roles.iconContainerBorder),
                ),
                child: Icon(icon, size: 28, color: roles.onIconContainer),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: roles.subtitle,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VodGridShimmer extends StatelessWidget {
  const _VodGridShimmer();

  @override
  Widget build(BuildContext context) {
    final roles = CatalogueSurfaceRoles.of(context);

    return Shimmer.fromColors(
      baseColor: roles.shimmerBase,
      highlightColor: roles.shimmerHighlight,
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: vodPosterAspectRatio,
        ),
        itemCount: 12,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: roles.shimmerTile,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
