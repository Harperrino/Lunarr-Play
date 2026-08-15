import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Detail page for movies, series and episodes.
class JellyfinDetailsView extends ConsumerStatefulWidget {
  const JellyfinDetailsView({
    super.key,
    required this.connection,
    required this.item,
  });

  final JellyfinConnection connection;
  final JellyfinItem item;

  @override
  ConsumerState<JellyfinDetailsView> createState() =>
      _JellyfinDetailsViewState();
}

class _JellyfinDetailsViewState extends ConsumerState<JellyfinDetailsView> {
  String? _busyAction;
  bool? _favoriteOverride;
  bool? _playedOverride;

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(jellyfinImageServiceProvider);
    final l10n = context.l10n;
    final detail = ref.watch(jellyfinItemDetailProvider(widget.item.id));
    final displayItem = detail.valueOrNull ?? widget.item;
    final favorite = _favoriteOverride ?? displayItem.favorite;
    final played = _playedOverride ?? displayItem.played;

    final posterUrl = images.posterUrl(
      widget.connection,
      itemId: displayItem.id,
      imageTag: displayItem.primaryImageTag,
    );
    final backdropUrl = images.backdropUrl(
      widget.connection,
      itemId: displayItem.backdropItemId ?? displayItem.id,
      imageTag: displayItem.backdropImageTag,
    );
    final logoUrl = images.logoUrl(
      widget.connection,
      itemId: displayItem.id,
      imageTag: displayItem.logoImageTag,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailHero(
                      item: displayItem,
                      posterUrl: posterUrl,
                      backdropUrl: backdropUrl,
                      logoUrl: logoUrl,
                      favorite: favorite,
                      played: played,
                      busyAction: _busyAction,
                      onBack: () => jellyfinGoBack(ref),
                      onPlay: displayItem.isSeries
                          ? null
                          : () => jellyfinOpenPlayer(ref, displayItem),
                      onTrailer: displayItem.remoteTrailers.isEmpty
                          ? null
                          : () =>
                                _openTrailer(displayItem.remoteTrailers.first),
                      onToggleFavorite: () =>
                          _toggleFavorite(displayItem, currentValue: favorite),
                      onTogglePlayed: () =>
                          _togglePlayed(displayItem, currentValue: played),
                    ),
                    if (constraints.maxWidth >= 700 &&
                        constraints.maxWidth < 1050)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _RatingAndProviderStrip(item: displayItem),
                                _Overview(item: displayItem, compact: false),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DetailFacts(item: displayItem),
                              if (displayItem.isSeries) ...[
                                const SizedBox(height: 28),
                                _EpisodeSeasons(
                                  connection: widget.connection,
                                  seriesId: displayItem.id,
                                ),
                              ],
                              if (detail.hasError) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n.jellyfinLoadFailed,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(
    JellyfinItem item, {
    required bool currentValue,
  }) async {
    if (_busyAction != null) return;
    final nextValue = !currentValue;
    setState(() {
      _busyAction = 'favorite';
      _favoriteOverride = nextValue;
    });
    try {
      final api = ref.read(jellyfinApiClientProvider);
      if (nextValue) {
        await api.markFavorite(widget.connection, itemId: item.id);
      } else {
        await api.unmarkFavorite(widget.connection, itemId: item.id);
      }
      if (!mounted) return;
      setState(() => _busyAction = null);
      ref.invalidate(jellyfinItemDetailProvider(item.id));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyAction = null;
        _favoriteOverride = currentValue;
      });
      _showActionError(error);
    }
  }

  Future<void> _togglePlayed(
    JellyfinItem item, {
    required bool currentValue,
  }) async {
    if (_busyAction != null) return;
    final nextValue = !currentValue;
    setState(() {
      _busyAction = 'played';
      _playedOverride = nextValue;
    });
    try {
      final api = ref.read(jellyfinApiClientProvider);
      if (nextValue) {
        await api.markPlayed(widget.connection, itemId: item.id);
      } else {
        await api.markUnplayed(widget.connection, itemId: item.id);
      }
      if (!mounted) return;
      setState(() => _busyAction = null);
      ref.invalidate(jellyfinItemDetailProvider(item.id));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyAction = null;
        _playedOverride = currentValue;
      });
      _showActionError(error);
    }
  }

  Future<void> _openTrailer(JellyfinTrailer trailer) async {
    final uri = Uri.tryParse(trailer.url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showTrailerError();
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) _showTrailerError();
  }

  void _showActionError(Object error) {
    final message = error is JellyfinApiException && error.message.isNotEmpty
        ? error.message
        : context.l10n.jellyfinStatusSaveFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showTrailerError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.jellyfinTrailerOpenFailed)),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.item,
    required this.posterUrl,
    required this.backdropUrl,
    required this.logoUrl,
    required this.favorite,
    required this.played,
    required this.busyAction,
    required this.onBack,
    required this.onPlay,
    required this.onTrailer,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
  });

  final JellyfinItem item;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final bool favorite;
  final bool played;
  final String? busyAction;
  final VoidCallback onBack;
  final VoidCallback? onPlay;
  final VoidCallback? onTrailer;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return _CompactHero(
            item: item,
            posterUrl: posterUrl,
            backdropUrl: backdropUrl,
            logoUrl: logoUrl,
            favorite: favorite,
            played: played,
            busyAction: busyAction,
            onBack: onBack,
            onPlay: onPlay,
            onTrailer: onTrailer,
            onToggleFavorite: onToggleFavorite,
            onTogglePlayed: onTogglePlayed,
          );
        }

        final isWide = constraints.maxWidth >= 1050;
        final posterWidth = isWide ? 220.0 : 160.0;
        final posterHeight = posterWidth * 1.5;
        return _HeroBackdrop(
          imageUrl: backdropUrl,
          height: isWide ? 520 : 430,
          onBack: onBack,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _HeroDetails(
                  item: item,
                  logoUrl: logoUrl,
                  favorite: favorite,
                  played: played,
                  busyAction: busyAction,
                  compact: false,
                  showRatings: isWide,
                  showOverview: isWide,
                  onPlay: onPlay,
                  onTrailer: onTrailer,
                  onToggleFavorite: onToggleFavorite,
                  onTogglePlayed: onTogglePlayed,
                ),
              ),
              const SizedBox(width: 24),
              _DetailPoster(
                key: const ValueKey('jellyfin-detail-poster'),
                imageUrl: posterUrl,
                fallbackIcon: item.isSeries
                    ? Icons.tv_rounded
                    : Icons.movie_rounded,
                width: posterWidth,
                height: posterHeight,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactHero extends StatelessWidget {
  const _CompactHero({
    required this.item,
    required this.posterUrl,
    required this.backdropUrl,
    required this.logoUrl,
    required this.favorite,
    required this.played,
    required this.busyAction,
    required this.onBack,
    required this.onPlay,
    required this.onTrailer,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
  });

  final JellyfinItem item;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final bool favorite;
  final bool played;
  final String? busyAction;
  final VoidCallback onBack;
  final VoidCallback? onPlay;
  final VoidCallback? onTrailer;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final backdropHeight = (constraints.maxWidth * 9 / 16)
            .clamp(180.0, 420.0)
            .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroBackdrop(
              imageUrl: backdropUrl,
              height: backdropHeight,
              onBack: onBack,
              child: const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailPoster(
                        key: const ValueKey('jellyfin-detail-poster'),
                        imageUrl: posterUrl,
                        fallbackIcon: item.isSeries
                            ? Icons.tv_rounded
                            : Icons.movie_rounded,
                        width: 112,
                        height: 168,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TitleAndMetadata(
                          item: item,
                          logoUrl: logoUrl,
                          compact: true,
                          onResume: onPlay,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _RatingAndProviderStrip(item: item),
                  _Overview(item: item, compact: true),
                  _DetailActions(
                    item: item,
                    favorite: favorite,
                    played: played,
                    busyAction: busyAction,
                    onPlay: onPlay,
                    onTrailer: onTrailer,
                    onToggleFavorite: onToggleFavorite,
                    onTogglePlayed: onTogglePlayed,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({
    required this.imageUrl,
    required this.height,
    required this.onBack,
    required this.child,
  });

  final String? imageUrl;
  final double height;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: _BackdropImage(imageUrl: imageUrl)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surface.withValues(alpha: 0.18),
                      colors.surface.withValues(alpha: 0.34),
                      colors.surface.withValues(alpha: 0.94),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton.filledTonal(
                tooltip: context.l10n.commonBackTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 72, 28, 24),
                child: Align(alignment: Alignment.bottomCenter, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackdropImage extends StatelessWidget {
  const _BackdropImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl;
    if (url == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.surfaceContainerHigh, colors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 2160,
      placeholder: (_, _) => DecoratedBox(
        decoration: BoxDecoration(color: colors.surfaceContainerHigh),
      ),
      errorWidget: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(color: colors.surfaceContainerHigh),
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HeroDetails extends StatelessWidget {
  const _HeroDetails({
    required this.item,
    required this.logoUrl,
    required this.favorite,
    required this.played,
    required this.busyAction,
    required this.compact,
    required this.showRatings,
    required this.showOverview,
    required this.onPlay,
    required this.onTrailer,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
  });

  final JellyfinItem item;
  final String? logoUrl;
  final bool favorite;
  final bool played;
  final String? busyAction;
  final bool compact;
  final bool showRatings;
  final bool showOverview;
  final VoidCallback? onPlay;
  final VoidCallback? onTrailer;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TitleAndMetadata(
          item: item,
          logoUrl: logoUrl,
          compact: compact,
          onResume: onPlay,
        ),
        if (showRatings) ...[
          const SizedBox(height: 14),
          _RatingAndProviderStrip(item: item),
        ],
        if (showOverview) _Overview(item: item, compact: compact),
        _DetailActions(
          item: item,
          favorite: favorite,
          played: played,
          busyAction: busyAction,
          onPlay: onPlay,
          onTrailer: onTrailer,
          onToggleFavorite: onToggleFavorite,
          onTogglePlayed: onTogglePlayed,
        ),
      ],
    );
  }
}

class _TitleAndMetadata extends StatelessWidget {
  const _TitleAndMetadata({
    required this.item,
    required this.logoUrl,
    required this.compact,
    required this.onResume,
  });

  final JellyfinItem item;
  final String? logoUrl;
  final bool compact;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoOrTitle(item: item, logoUrl: logoUrl, compact: compact),
        if (item.seriesName != null && item.seriesName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.seriesName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _metadataChips(l10n, item)),
        if (item.hasResume) ...[
          const SizedBox(height: 10),
          _ResumeProgress(item: item, onPressed: onResume),
        ],
      ],
    );
  }

  List<Widget> _metadataChips(AppLocalizations l10n, JellyfinItem item) {
    final chips = <Widget>[];
    if (item.isEpisode) {
      final seasonEpisode = jellyfinSeasonEpisodeLabel(
        l10n,
        season: item.seasonNumber,
        episode: item.episodeNumber,
      );
      if (seasonEpisode.isNotEmpty) chips.add(Chip(label: Text(seasonEpisode)));
    } else if (item.productionYear != null) {
      chips.add(Chip(label: Text(item.productionYear.toString())));
    }
    if (item.officialRating?.isNotEmpty ?? false) {
      chips.add(Chip(label: Text(item.officialRating!)));
    }
    if (item.runTimeTicks > 0) {
      chips.add(
        Chip(label: Text(jellyfinRuntimeLabel(l10n, item.runTimeTicks))),
      );
    }
    return chips;
  }
}

class _LogoOrTitle extends StatelessWidget {
  const _LogoOrTitle({
    required this.item,
    required this.logoUrl,
    required this.compact,
  });

  final JellyfinItem item;
  final String? logoUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle =
        (compact ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall)
            ?.copyWith(fontWeight: FontWeight.w800);
    final url = logoUrl;
    return Semantics(
      label: item.name,
      child: url == null
          ? Text(
              item.name,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            )
          : SizedBox(
              height: compact ? 58 : 78,
              width: compact ? 240 : 340,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                memCacheWidth: 700,
                errorWidget: (_, _, _) => Text(
                  item.name,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
            ),
    );
  }
}

class _RatingAndProviderStrip extends StatelessWidget {
  const _RatingAndProviderStrip({required this.item});

  final JellyfinItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final children = <Widget>[];
    if (item.communityRating != null) {
      children.add(
        _RatingCard(
          label: l10n.jellyfinCommunityRating,
          value: item.communityRating!.toStringAsFixed(1),
          icon: Icons.people_alt_rounded,
        ),
      );
    }
    if (item.criticRating != null) {
      children.add(
        _RatingCard(
          label: l10n.jellyfinCriticRating,
          value: '${item.criticRating!.round()}%',
          icon: Icons.rate_review_rounded,
        ),
      );
    }
    final imdb = _providerId(item.providerIds, const ['imdb']);
    final tmdb = _providerId(item.providerIds, const ['tmdb', 'themoviedb']);
    final imdbUri = imdb == null ? null : _providerUri(item, 'imdb', imdb);
    final tmdbUri = tmdb == null ? null : _providerUri(item, 'tmdb', tmdb);
    if (imdbUri != null) {
      children.add(
        ActionChip(
          avatar: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(l10n.jellyfinImdbProviderLabel),
          tooltip: l10n.jellyfinOpenProviderTooltip(
            l10n.jellyfinImdbProviderLabel,
          ),
          onPressed: () => unawaited(_openProvider(context, imdbUri)),
        ),
      );
    }
    if (tmdbUri != null) {
      children.add(
        ActionChip(
          avatar: const Icon(Icons.open_in_new_rounded, size: 16),
          label: Text(l10n.jellyfinTmdbProviderLabel),
          tooltip: l10n.jellyfinOpenProviderTooltip(
            l10n.jellyfinTmdbProviderLabel,
          ),
          onPressed: () => unawaited(_openProvider(context, tmdbUri)),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.item, required this.compact});

  final JellyfinItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (item.overview.isEmpty && item.taglines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.taglines.isNotEmpty)
            Text(
              item.taglines.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.overview.isNotEmpty) ...[
            if (item.taglines.isNotEmpty) const SizedBox(height: 6),
            Text(
              item.overview,
              maxLines: compact ? 6 : 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.item,
    required this.favorite,
    required this.played,
    required this.busyAction,
    required this.onPlay,
    required this.onTrailer,
    required this.onToggleFavorite,
    required this.onTogglePlayed,
  });

  final JellyfinItem item;
  final bool favorite;
  final bool played;
  final String? busyAction;
  final VoidCallback? onPlay;
  final VoidCallback? onTrailer;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePlayed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disabled = busyAction != null;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (onPlay != null)
            FilledButton.icon(
              onPressed: disabled ? null : onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.jellyfinPlay),
            ),
          if (onTrailer != null)
            FilledButton.tonalIcon(
              onPressed: disabled ? null : onTrailer,
              icon: const Icon(Icons.movie_filter_rounded),
              label: Text(l10n.jellyfinTrailer),
            ),
          OutlinedButton.icon(
            onPressed: disabled ? null : onToggleFavorite,
            icon: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            ),
            label: Text(
              favorite ? l10n.jellyfinRemoveFavorite : l10n.jellyfinFavorite,
            ),
          ),
          OutlinedButton.icon(
            onPressed: disabled ? null : onTogglePlayed,
            icon: Icon(played ? Icons.visibility_rounded : Icons.check_rounded),
            label: Text(
              played ? l10n.jellyfinMarkUnwatched : l10n.jellyfinMarkWatched,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeProgress extends StatelessWidget {
  const _ResumeProgress({required this.item, required this.onPressed});

  final JellyfinItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: const Icon(Icons.play_circle_rounded),
          label: Text(context.l10n.jellyfinResumeLabel),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: item.resumeFraction,
              minHeight: 4,
              backgroundColor: colors.surfaceContainerHigh,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailPoster extends StatelessWidget {
  const _DetailPoster({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.width,
    required this.height,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _PosterFallback(icon: fallbackIcon, colors: colors)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (width * 2).round(),
                placeholder: (_, _) =>
                    _PosterFallback(icon: fallbackIcon, colors: colors),
                errorWidget: (_, _, _) =>
                    _PosterFallback(icon: fallbackIcon, colors: colors),
              ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.icon, required this.colors});

  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: Icon(icon, size: 34, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _DetailFacts extends StatelessWidget {
  const _DetailFacts({required this.item});

  final JellyfinItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final directors = _peopleByRole(item.people, const ['director']);
    final writers = _peopleByRole(item.people, const ['writer', 'screenplay']);
    final facts = <_FactData>[
      if (item.genres.isNotEmpty)
        _FactData(label: l10n.jellyfinGenres, values: item.genres),
      if (directors.isNotEmpty)
        _FactData(label: l10n.jellyfinDirectors, values: directors),
      if (writers.isNotEmpty)
        _FactData(label: l10n.jellyfinWriters, values: writers),
      if (item.studios.isNotEmpty)
        _FactData(label: l10n.jellyfinStudios, values: item.studios),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return AppSurface(
      level: AppSurfaceLevel.low,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 700
              ? (constraints.maxWidth - 48) / 4
              : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 20,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: width,
                  child: _FactColumn(fact: fact),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FactData {
  const _FactData({required this.label, required this.values});

  final String label;
  final List<String> values;
}

class _FactColumn extends StatelessWidget {
  const _FactColumn({required this.fact});

  final _FactData fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fact.label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        Text(fact.values.join(', '), style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

List<String> _peopleByRole(List<JellyfinPerson> people, List<String> roles) {
  return people
      .where((person) {
        final value = '${person.role ?? ''} ${person.type ?? ''}'.toLowerCase();
        return roles.any(value.contains);
      })
      .map((person) => person.name)
      .toSet()
      .toList();
}

String? _providerId(Map<String, String> providerIds, List<String> names) {
  for (final entry in providerIds.entries) {
    final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (names.contains(key) && entry.value.isNotEmpty) return entry.value;
  }
  return null;
}

Uri? _providerUri(JellyfinItem item, String provider, String id) {
  if (provider == 'imdb' && RegExp(r'^tt\d+$').hasMatch(id)) {
    return Uri.https('www.imdb.com', '/title/$id/');
  }
  if (provider == 'tmdb' && RegExp(r'^\d+$').hasMatch(id)) {
    final mediaType = item.isSeries || item.isEpisode ? 'tv' : 'movie';
    return Uri.https('www.themoviedb.org', '/$mediaType/$id');
  }
  return null;
}

Future<void> _openProvider(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.jellyfinProviderOpenFailed)),
    );
  }
}

class _EpisodeSeasons extends ConsumerStatefulWidget {
  const _EpisodeSeasons({required this.connection, required this.seriesId});

  final JellyfinConnection connection;
  final String seriesId;

  @override
  ConsumerState<_EpisodeSeasons> createState() => _EpisodeSeasonsState();
}

class _EpisodeSeasonsState extends ConsumerState<_EpisodeSeasons> {
  int? _selectedSeason;

  @override
  Widget build(BuildContext context) {
    final episodes = ref.watch(
      jellyfinSeriesEpisodesProvider(widget.seriesId),
    );
    final l10n = context.l10n;
    final value = episodes.valueOrNull;

    return switch ((episodes.hasError, value)) {
      (true, null) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.jellyfinLoadFailed),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(
                  jellyfinSeriesEpisodesProvider(widget.seriesId).notifier,
                )
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
      (_, final data?) => _buildSeasonSelector(context, data),
    };
  }

  Widget _buildSeasonSelector(
    BuildContext context,
    List<JellyfinItem> episodes,
  ) {
    final l10n = context.l10n;
    final grouped = jellyfinGroupEpisodesBySeason(episodes);
    if (grouped.isEmpty) return const SizedBox.shrink();

    final selectedSeason = grouped.containsKey(_selectedSeason)
        ? _selectedSeason!
        : grouped.keys.first;
    final selectedEpisodes = grouped[selectedSeason]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final title = Text(
          l10n.jellyfinEpisodesTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        );
        final selector = DropdownMenu<int>(
          key: const ValueKey('jellyfin-season-selector'),
          width: compact ? constraints.maxWidth : 240,
          initialSelection: selectedSeason,
          label: Text(l10n.jellyfinSeasonSelectorLabel),
          leadingIcon: const Icon(Icons.video_library_rounded),
          dropdownMenuEntries: [
            for (final season in grouped.keys)
              DropdownMenuEntry<int>(
                value: season,
                label: l10n.jellyfinSeasonLabel(season),
              ),
          ],
          onSelected: (season) {
            if (season != null && season != _selectedSeason) {
              setState(() => _selectedSeason = season);
            }
          },
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact) ...[
              title,
              const SizedBox(height: 10),
              selector,
            ] else
              Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 16),
                  selector,
                ],
              ),
            const SizedBox(height: 14),
            for (final episode in selectedEpisodes)
              _EpisodeRow(
                connection: widget.connection,
                episode: episode,
                onTap: () => jellyfinOpenDetails(ref, episode),
              ),
          ],
        );
      },
    );
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
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
      return ColoredBox(
        color: colors.surfaceContainerHigh,
        child: const Center(child: Icon(Icons.tv_rounded, size: 20)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 200,
      placeholder: (_, _) => ColoredBox(color: colors.surfaceContainerHigh),
      errorWidget: (_, _, _) => ColoredBox(
        color: colors.surfaceContainerHigh,
        child: const Center(child: Icon(Icons.tv_rounded, size: 20)),
      ),
    );
  }
}
