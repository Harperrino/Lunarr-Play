import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/episode_card.dart';
import 'package:m3uxtream_player/shared/theme/catalogue_surface_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_tab_shelf.dart';
import 'package:shimmer/shimmer.dart';

/// Episode catalogue with season tabs and resume banner.
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesChannel,
    required this.onBack,
  });

  final Channel seriesChannel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(seriesEpisodesProvider(seriesChannel.id));
    final resumeAsync = ref.watch(seriesResumeProvider(seriesChannel.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(seriesChannel: seriesChannel, onBack: onBack),
        const SizedBox(height: 12),
        resumeAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (resume) {
            if (resume == null || resume.positionMs <= 0) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ResumeBanner(
                resume: resume,
                onContinue: () => _continueResume(ref, resume),
              ),
            );
          },
        ),
        Expanded(
          child: AppSurface(
            level: AppSurfaceLevel.high,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: episodesAsync.when(
              loading: () => const _EpisodeListShimmer(),
              error: (err, _) => _ErrorState(message: err.toString()),
              data: (episodes) => _buildEpisodeContent(context, ref, episodes),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeContent(
    BuildContext context,
    WidgetRef ref,
    List<ParsedSeriesEpisode> episodes,
  ) {
    if (episodes.isEmpty) {
      return const _EmptyEpisodeState();
    }

    if (episodes.length == 1 && episodes.first.season == null) {
      final episode = episodes.first;
      return Center(
        child: FilledButton.icon(
          onPressed: () => selectSeriesEpisodePrep(
            ref,
            seriesChannel: seriesChannel,
            episode: episode,
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 16),
          label: Text('Abspielen - ${episode.title}'),
        ),
      );
    }

    final grouped = groupEpisodesBySeason(episodes);
    final seasons = grouped.keys.toList();

    return DefaultTabController(
      length: seasons.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          M3TabShelf(
            padding: const EdgeInsets.all(6),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              labelColor: Theme.of(context).colorScheme.onSecondaryContainer,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                for (final season in seasons)
                  Tab(
                    text: season == 0
                        ? 'Episoden'
                        : 'S${season.toString().padLeft(2, '0')}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                for (final season in seasons)
                  ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: grouped[season]!.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final episode = grouped[season]![index];
                      return EpisodeCard(
                        title: episode.title,
                        subtitle: formatEpisodeSubtitle(episode),
                        onTap: () => selectSeriesEpisodePrep(
                          ref,
                          seriesChannel: seriesChannel,
                          episode: episode,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _continueResume(WidgetRef ref, SeriesResumeState resume) {
    final episode = ParsedSeriesEpisode(
      episodeId: resume.episodeId,
      title: resume.episodeTitle,
      streamUrl: resume.streamUrl,
      season: resume.season,
      episodeNum: resume.episodeNum,
    );
    selectSeriesEpisodePrep(
      ref,
      seriesChannel: seriesChannel,
      episode: episode,
      startPositionMs: resume.positionMs,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.seriesChannel, required this.onBack});

  final Channel seriesChannel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;

        return AppSurface(
          level: AppSurfaceLevel.standard,
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackButton(onBack: onBack),
                    const SizedBox(height: 12),
                    Text(
                      seriesChannel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (seriesChannel.groupName != null &&
                        seriesChannel.groupName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        seriesChannel.groupName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    _BackButton(onBack: onBack),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seriesChannel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (seriesChannel.groupName != null &&
                              seriesChannel.groupName!.isNotEmpty)
                            Text(
                              seriesChannel.groupName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      tooltip: 'Zurück',
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.resume, required this.onContinue});

  final SeriesResumeState resume;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.standard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              shape: const CircleBorder(),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weiterschauen',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  resume.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onContinue,
            child: const Text('Fortsetzen', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _EmptyEpisodeState extends StatelessWidget {
  const _EmptyEpisodeState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Keine Episoden gefunden.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _EpisodeListShimmer extends StatelessWidget {
  const _EpisodeListShimmer();

  @override
  Widget build(BuildContext context) {
    final roles = CatalogueSurfaceRoles.of(context);

    return Shimmer.fromColors(
      baseColor: roles.shimmerBase,
      highlightColor: roles.shimmerHighlight,
      enabled: !MediaQuery.disableAnimationsOf(context),
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: roles.shimmerTile,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
