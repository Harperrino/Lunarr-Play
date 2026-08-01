import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';

/// Detail page for movies, series and episodes.
class JellyfinDetailsView extends ConsumerWidget {
  const JellyfinDetailsView({
    super.key,
    required this.connection,
    required this.item,
  });

  final JellyfinConnection connection;
  final JellyfinItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(jellyfinImageServiceProvider);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.commonBackTooltip,
              onPressed: () => jellyfinGoBack(ref),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _Backdrop(
                imageUrl: images.backdropUrl(
                  connection,
                  itemId: item.id,
                  imageTag: item.backdropImageTag,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoBlock(
                          connection: connection,
                          item: item,
                        ),
                        if (item.isSeries) ...[
                          const SizedBox(height: 24),
                          _EpisodeSeasons(
                            connection: connection,
                            seriesId: item.id,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: url == null
            ? Container(
                color: colors.surfaceContainerHigh,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_rounded,
                    size: 36,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 1600,
                placeholder: (_, _) => Container(
                  color: colors.surfaceContainerHigh,
                ),
                errorWidget: (_, _, _) => Container(
                  color: colors.surfaceContainerHigh,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      size: 36,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _InfoBlock extends ConsumerWidget {
  const _InfoBlock({required this.connection, required this.item});

  final JellyfinConnection connection;
  final JellyfinItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final images = ref.watch(jellyfinImageServiceProvider);
    final posterUrl = images.posterUrl(
      connection,
      itemId: item.id,
      imageTag: item.primaryImageTag,
    );
    final meta = _metaLine(l10n, item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 140,
            height: 210,
            child: _DetailPoster(
              imageUrl: posterUrl,
              fallbackIcon: item.isSeries
                  ? Icons.tv_rounded
                  : Icons.movie_rounded,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.seriesName != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.seriesName!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (item.hasResume) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    MediaMetadataBadge(
                      label: l10n.jellyfinResumeLabel,
                      icon: Icons.play_circle_rounded,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: item.resumeFraction,
                          minHeight: 4,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!item.isSeries) ...[
                const SizedBox(height: 18),
                Tooltip(
                  message: l10n.jellyfinPlaybackUnavailableTooltip,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.jellyfinPlay),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
              if (item.overview.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  item.overview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _metaLine(AppLocalizations l10n, JellyfinItem item) {
    if (item.isEpisode) {
      return jellyfinSeasonEpisodeLabel(
        l10n,
        season: item.seasonNumber,
        episode: item.episodeNumber,
      );
    }
    final year = item.productionYear?.toString() ?? '';
    final runtime = item.runTimeTicks > 0
        ? jellyfinRuntimeLabel(l10n, item.runTimeTicks)
        : '';
    if (year.isEmpty) return runtime;
    if (runtime.isEmpty) return year;
    return l10n.jellyfinMetaLine(year, runtime);
  }
}

class _DetailPoster extends StatelessWidget {
  const _DetailPoster({required this.imageUrl, required this.fallbackIcon});

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl;

    if (url == null) {
      return Container(
        color: colors.surfaceContainerHigh,
        child: Center(
          child: Icon(fallbackIcon, size: 34, color: colors.onSurfaceVariant),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (_, _) => Container(color: colors.surfaceContainerHigh),
      errorWidget: (_, _, _) => Container(
        color: colors.surfaceContainerHigh,
        child: Center(
          child: Icon(fallbackIcon, size: 34, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EpisodeSeasons extends ConsumerWidget {
  const _EpisodeSeasons({
    required this.connection,
    required this.seriesId,
  });

  final JellyfinConnection connection;
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodes = ref.watch(jellyfinSeriesEpisodesProvider(seriesId));
    final l10n = context.l10n;
    final value = episodes.valueOrNull;

    return switch ((episodes.hasError, value)) {
      (true, null) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.jellyfinLoadFailed,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(jellyfinSeriesEpisodesProvider(seriesId).notifier)
                .refresh(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.commonRetry),
          ),
        ],
      ),
      (_, null) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      (_, final data?) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry
              in jellyfinGroupEpisodesBySeason(data).entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.jellyfinSeasonLabel(entry.key),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final episode in entry.value)
              _EpisodeRow(
                connection: connection,
                episode: episode,
                onTap: () => jellyfinOpenDetails(ref, episode),
              ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    };
  }
}

class _EpisodeRow extends ConsumerWidget {
  const _EpisodeRow({
    required this.connection,
    required this.episode,
    required this.onTap,
  });

  final JellyfinConnection connection;
  final JellyfinItem episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final images = ref.watch(jellyfinImageServiceProvider);
    final runtime = episode.runTimeTicks > 0
        ? jellyfinRuntimeLabel(l10n, episode.runTimeTicks)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 100,
                    height: 56,
                    child: _EpisodeThumb(
                      imageUrl: images.posterUrl(
                        connection,
                        itemId: episode.id,
                        imageTag: episode.primaryImageTag,
                        maxWidth: 200,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (episode.episodeNumber != null) ...[
                            Text(
                              l10n.jellyfinEpisodeNumberLabel(
                                episode.episodeNumber!,
                              ),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              episode.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (runtime.isNotEmpty)
                            Text(
                              runtime,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                      if (episode.overview.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          episode.overview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (episode.hasResume) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: episode.resumeFraction,
                            minHeight: 3,
                            backgroundColor: colors.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  const _EpisodeThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl;

    if (url == null) {
      return Container(
        color: colors.surfaceContainerHigh,
        child: const Center(child: Icon(Icons.tv_rounded, size: 20)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 200,
      placeholder: (_, _) => Container(color: colors.surfaceContainerHigh),
      errorWidget: (_, _, _) => Container(
        color: colors.surfaceContainerHigh,
        child: const Center(child: Icon(Icons.tv_rounded, size: 20)),
      ),
    );
  }
}
