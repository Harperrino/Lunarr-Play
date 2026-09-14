import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_episode_catalog.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_episode_detail_pane.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Responsive series episode catalog.
///
/// Wide layouts keep selection and details together; compact layouts retain
/// the established separate detail route.
class JellyfinSeriesEpisodeBrowser extends ConsumerStatefulWidget {
  const JellyfinSeriesEpisodeBrowser({
    super.key,
    required this.connection,
    required this.seriesId,
  });

  final JellyfinConnection connection;
  final String seriesId;

  @override
  ConsumerState<JellyfinSeriesEpisodeBrowser> createState() =>
      _JellyfinSeriesEpisodeBrowserState();
}

class _JellyfinSeriesEpisodeBrowserState
    extends ConsumerState<JellyfinSeriesEpisodeBrowser> {
  int? _selectedSeason;
  String? _selectedEpisodeId;

  @override
  void didUpdateWidget(JellyfinSeriesEpisodeBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesId != widget.seriesId ||
        oldWidget.connection.credentialId != widget.connection.credentialId) {
      _selectedSeason = null;
      _selectedEpisodeId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodes = ref.watch(jellyfinSeriesEpisodesProvider(widget.seriesId));
    final data = episodes.valueOrNull;
    if (data == null) {
      if (episodes.hasError) {
        return _EpisodeLoadError(
          onRetry: () => ref
              .read(jellyfinSeriesEpisodesProvider(widget.seriesId).notifier)
              .refresh(),
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final catalog = JellyfinEpisodeCatalog.fromEpisodes(data);
    if (catalog.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(context.l10n.jellyfinNoEpisodes),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final season = catalog.normalizedSeason(_selectedSeason)!;
        final seasonEpisodes = catalog.episodesForSeason(season);
        final selectedEpisode = seasonEpisodes.firstWhere(
          (episode) => episode.id == _selectedEpisodeId,
          orElse: () => seasonEpisodes.first,
        );
        return Column(
          key: ValueKey('jellyfin-episode-browser-${widget.seriesId}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.jellyfinEpisodesTitle,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownMenu<int>(
              key: const ValueKey('jellyfin-season-selector'),
              width: wide ? 260 : constraints.maxWidth,
              initialSelection: season,
              label: Text(context.l10n.jellyfinSeasonSelectorLabel),
              leadingIcon: const Icon(Icons.video_library_rounded),
              dropdownMenuEntries: [
                for (final value in catalog.seasons)
                  DropdownMenuEntry<int>(
                    value: value,
                    label: context.l10n.jellyfinSeasonLabel(value),
                  ),
              ],
              onSelected: (value) {
                if (value == null || value == season) return;
                setState(() {
                  _selectedSeason = value;
                  _selectedEpisodeId = catalog.firstEpisodeForSeason(value)?.id;
                });
              },
            ),
            const SizedBox(height: 16),
            if (wide)
              SizedBox(
                height: 660,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 1050 ? 340 : 400,
                      child: AppSurface(
                        level: AppSurfaceLevel.low,
                        padding: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: _EpisodeList(
                          connection: widget.connection,
                          episodes: seasonEpisodes,
                          selectedEpisodeId: selectedEpisode.id,
                          onSelect: (episode) {
                            setState(() => _selectedEpisodeId = episode.id);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: JellyfinEpisodeDetailPane(
                        connection: widget.connection,
                        episode: selectedEpisode,
                      ),
                    ),
                  ],
                ),
              )
            else
              _EpisodeList(
                connection: widget.connection,
                episodes: seasonEpisodes,
                selectedEpisodeId: null,
                shrinkWrap: true,
                onSelect: (episode) => jellyfinOpenDetails(ref, episode),
              ),
          ],
        );
      },
    );
  }
}

class _EpisodeLoadError extends StatelessWidget {
  const _EpisodeLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.jellyfinLoadFailed),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(context.l10n.commonRetry),
        ),
      ],
    );
  }
}

class _EpisodeList extends StatelessWidget {
  const _EpisodeList({
    required this.connection,
    required this.episodes,
    required this.selectedEpisodeId,
    required this.onSelect,
    this.shrinkWrap = false,
  });

  final JellyfinConnection connection;
  final List<JellyfinItem> episodes;
  final String? selectedEpisodeId;
  final ValueChanged<JellyfinItem> onSelect;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: ValueKey(
        'jellyfin-season-episode-list-${episodes.first.seasonNumber}',
      ),
      primary: false,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: episodes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        return _EpisodeRow(
          connection: connection,
          episode: episode,
          selected: episode.id == selectedEpisodeId,
          onTap: () => onSelect(episode),
        );
      },
    );
  }
}

class _EpisodeRow extends ConsumerWidget {
  const _EpisodeRow({
    required this.connection,
    required this.episode,
    required this.selected,
    required this.onTap,
  });

  final JellyfinConnection connection;
  final JellyfinItem episode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = ref
        .watch(jellyfinImageServiceProvider)
        .posterUrl(
          connection,
          itemId: episode.id,
          imageTag: episode.primaryImageTag,
        );
    final episodeLabel = episode.episodeNumber == null
        ? jellyfinSeasonEpisodeLabel(
            context.l10n,
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
          )
        : context.l10n.jellyfinEpisodeNumberLabel(episode.episodeNumber!);
    return Semantics(
      selected: selected,
      button: true,
      label: context.l10n.jellyfinEpisodeSemantics(episodeLabel, episode.name),
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('jellyfin-episode-row-${episode.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 104,
                    height: 62,
                    child: imageUrl == null
                        ? const _EpisodeThumbFallback()
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            errorWidget: (_, _, _) =>
                                const _EpisodeThumbFallback(),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodeLabel,
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
                          maxLines: 2,
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
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
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

class _EpisodeThumbFallback extends StatelessWidget {
  const _EpisodeThumbFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.movie_filter_rounded, color: colors.onSurfaceVariant),
    );
  }
}
