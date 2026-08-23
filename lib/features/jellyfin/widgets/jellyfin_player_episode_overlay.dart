import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_episode_catalog.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';

/// Provider-free player overlay for browsing episodes by season.
class JellyfinPlayerEpisodeOverlay extends StatelessWidget {
  const JellyfinPlayerEpisodeOverlay({
    super.key,
    required this.connection,
    required this.imageService,
    required this.catalog,
    required this.selectedSeason,
    required this.currentItemId,
    required this.loading,
    required this.switchingEpisode,
    required this.hasError,
    required this.onSeasonSelected,
    required this.onSelect,
    required this.onRetry,
    required this.onClose,
    this.closeFocusNode,
  });

  final JellyfinConnection connection;
  final JellyfinImageService imageService;
  final JellyfinEpisodeCatalog catalog;
  final int? selectedSeason;
  final String currentItemId;
  final bool loading;
  final bool switchingEpisode;
  final bool hasError;
  final ValueChanged<int> onSeasonSelected;
  final ValueChanged<JellyfinItem> onSelect;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final FocusNode? closeFocusNode;

  @override
  Widget build(BuildContext context) {
    final season = catalog.normalizedSeason(selectedSeason);
    final episodes = season == null
        ? const <JellyfinItem>[]
        : catalog.episodesForSeason(season);
    return AppOverlaySurface(
      key: const ValueKey('jellyfin-episode-picker'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        key: const ValueKey('jellyfin-player-episode-overlay'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.jellyfinEpisodesTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Focus(
                focusNode: closeFocusNode,
                child: IconButton.filledTonal(
                  key: const ValueKey('jellyfin-episode-overlay-close'),
                  tooltip: context.l10n.jellyfinHideEpisodesTooltip,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
          if (catalog.seasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => M3DropdownField<int>(
                key: ValueKey('jellyfin-player-season-selector-$season'),
                width: constraints.maxWidth,
                value: season!,
                label: Text(context.l10n.jellyfinSeasonSelectorLabel),
                leadingIcon: const Icon(Icons.video_library_rounded),
                entries: [
                  for (final value in catalog.seasons)
                    DropdownMenuEntry<int>(
                      value: value,
                      label: context.l10n.jellyfinSeasonLabel(value),
                    ),
                ],
                onSelected: (value) {
                  if (value != null && value != season) {
                    onSeasonSelected(value);
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(child: _buildBody(context, episodes)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<JellyfinItem> episodes) {
    if (loading && catalog.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (hasError && catalog.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.jellyfinLoadFailed),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (episodes.isEmpty) {
      return Center(child: Text(context.l10n.jellyfinNoEpisodes));
    }
    return ListView.separated(
      primary: false,
      itemCount: episodes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final current = episode.id == currentItemId;
        return _OverlayEpisodeRow(
          connection: connection,
          imageService: imageService,
          episode: episode,
          current: current,
          enabled: !current && !switchingEpisode,
          onTap: () => onSelect(episode),
        );
      },
    );
  }
}

class _OverlayEpisodeRow extends StatelessWidget {
  const _OverlayEpisodeRow({
    required this.connection,
    required this.imageService,
    required this.episode,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final JellyfinConnection connection;
  final JellyfinImageService imageService;
  final JellyfinItem episode;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = jellyfinSeasonEpisodeLabel(
      context.l10n,
      season: episode.seasonNumber,
      episode: episode.episodeNumber,
    );
    final imageUrl = imageService.posterUrl(
      connection,
      itemId: episode.id,
      imageTag: episode.primaryImageTag,
      maxWidth: 240,
    );
    return Semantics(
      selected: current,
      button: true,
      enabled: enabled,
      label: context.l10n.jellyfinEpisodeSemantics(label, episode.name),
      child: Material(
        color: current
            ? colors.secondaryContainer
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('jellyfin-player-episode-${episode.id}'),
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 112,
                    height: 66,
                    child: imageUrl == null
                        ? const _OverlayImageFallback()
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            fadeInDuration: Duration.zero,
                            errorWidget: (_, _, _) =>
                                const _OverlayImageFallback(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        episode.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (episode.overview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          episode.overview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (episode.hasResume) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: episode.resumeFraction,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ],
                    ],
                  ),
                ),
                if (current)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.play_circle_filled_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayImageFallback extends StatelessWidget {
  const _OverlayImageFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.tv_rounded, color: colors.onSurfaceVariant),
    );
  }
}
