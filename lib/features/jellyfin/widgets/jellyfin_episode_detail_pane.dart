import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_exception.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Embedded episode detail surface used by the wide series master/detail view.
class JellyfinEpisodeDetailPane extends ConsumerStatefulWidget {
  const JellyfinEpisodeDetailPane({
    super.key,
    required this.connection,
    required this.episode,
  });

  final JellyfinConnection connection;
  final JellyfinItem episode;

  @override
  ConsumerState<JellyfinEpisodeDetailPane> createState() =>
      _JellyfinEpisodeDetailPaneState();
}

class _JellyfinEpisodeDetailPaneState
    extends ConsumerState<JellyfinEpisodeDetailPane> {
  String? _busyAction;
  bool? _favoriteOverride;
  bool? _playedOverride;
  int _actionGeneration = 0;

  String get _identity =>
      '${widget.connection.credentialId}:${widget.episode.id}';

  @override
  void didUpdateWidget(JellyfinEpisodeDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.id != widget.episode.id ||
        oldWidget.connection.credentialId != widget.connection.credentialId) {
      _actionGeneration++;
      _busyAction = null;
      _favoriteOverride = null;
      _playedOverride = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(jellyfinItemDetailProvider(widget.episode.id));
    final item = detail.valueOrNull ?? widget.episode;
    final favorite = _favoriteOverride ?? item.favorite;
    final played = _playedOverride ?? item.played;
    final images = ref.watch(jellyfinImageServiceProvider);
    final imageUrl = images.posterUrl(
      widget.connection,
      itemId: item.id,
      imageTag: item.primaryImageTag,
    );
    final metadata = <String>[
      jellyfinSeasonEpisodeLabel(
        context.l10n,
        season: item.seasonNumber,
        episode: item.episodeNumber,
      ),
      if (item.runTimeTicks > 0)
        jellyfinRuntimeLabel(context.l10n, item.runTimeTicks),
      if (item.productionYear != null) '${item.productionYear}',
      if (item.officialRating?.isNotEmpty ?? false) item.officialRating!,
    ].where((value) => value.isNotEmpty).toList(growable: false);

    return AppSurface(
      key: ValueKey('jellyfin-episode-detail-${item.id}'),
      level: AppSurfaceLevel.high,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: imageUrl == null
                      ? const _EpisodeArtworkFallback()
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, _, _) =>
                              const _EpisodeArtworkFallback(),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              if (metadata.isNotEmpty)
                Text(
                  metadata.join(' · '),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                item.name,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (item.hasResume) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: context.l10n.jellyfinResumeLabel,
                  value: '${(item.resumeFraction * 100).round()}%',
                  child: LinearProgressIndicator(
                    value: item.resumeFraction.clamp(0, 1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
              if (item.overview.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  context.l10n.jellyfinOverview,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  item.overview,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('jellyfin-embedded-episode-play'),
                    onPressed: _busyAction == null
                        ? () => jellyfinOpenPlayer(ref, item)
                        : null,
                    icon: Icon(
                      item.hasResume
                          ? Icons.play_circle_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      item.hasResume
                          ? context.l10n.jellyfinResumeLabel
                          : context.l10n.jellyfinPlay,
                    ),
                  ),
                  FilterChip(
                    key: const ValueKey('jellyfin-embedded-episode-favorite'),
                    selected: favorite,
                    onSelected: _busyAction == null
                        ? (_) => unawaited(
                            _toggleFavorite(item, currentValue: favorite),
                          )
                        : null,
                    avatar: Icon(
                      favorite ? Icons.favorite_rounded : Icons.favorite_border,
                      size: 18,
                    ),
                    label: Text(
                      favorite
                          ? context.l10n.jellyfinRemoveFavorite
                          : context.l10n.jellyfinFavorite,
                    ),
                  ),
                  FilterChip(
                    key: const ValueKey('jellyfin-embedded-episode-played'),
                    selected: played,
                    onSelected: _busyAction == null
                        ? (_) => unawaited(
                            _togglePlayed(item, currentValue: played),
                          )
                        : null,
                    avatar: Icon(
                      played
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      played
                          ? context.l10n.jellyfinMarkUnwatched
                          : context.l10n.jellyfinMarkWatched,
                    ),
                  ),
                ],
              ),
              if (detail.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.jellyfinLoadFailed,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(
    JellyfinItem item, {
    required bool currentValue,
  }) async {
    if (_busyAction != null) return;
    final generation = _actionGeneration;
    final identity = _identity;
    final connection = widget.connection;
    final nextValue = !currentValue;
    setState(() {
      _busyAction = 'favorite';
      _favoriteOverride = nextValue;
    });
    try {
      final api = ref.read(jellyfinApiClientProvider);
      if (nextValue) {
        await api.markFavorite(connection, itemId: item.id);
      } else {
        await api.unmarkFavorite(connection, itemId: item.id);
      }
      if (mounted) ref.invalidate(jellyfinItemDetailProvider(item.id));
      if (_isCurrent(generation, identity)) {
        setState(() => _busyAction = null);
      }
    } catch (error) {
      if (!_isCurrent(generation, identity)) return;
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
    final generation = _actionGeneration;
    final identity = _identity;
    final connection = widget.connection;
    final nextValue = !currentValue;
    setState(() {
      _busyAction = 'played';
      _playedOverride = nextValue;
    });
    try {
      final api = ref.read(jellyfinApiClientProvider);
      if (nextValue) {
        await api.markPlayed(connection, itemId: item.id);
      } else {
        await api.markUnplayed(connection, itemId: item.id);
      }
      if (mounted) ref.invalidate(jellyfinItemDetailProvider(item.id));
      if (_isCurrent(generation, identity)) {
        setState(() => _busyAction = null);
      }
    } catch (error) {
      if (!_isCurrent(generation, identity)) return;
      setState(() {
        _busyAction = null;
        _playedOverride = currentValue;
      });
      _showActionError(error);
    }
  }

  bool _isCurrent(int generation, String identity) =>
      mounted && generation == _actionGeneration && identity == _identity;

  void _showActionError(Object error) {
    final message = error is JellyfinApiException && error.message.isNotEmpty
        ? error.message
        : context.l10n.jellyfinStatusSaveFailed;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EpisodeArtworkFallback extends StatelessWidget {
  const _EpisodeArtworkFallback();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(
        Icons.movie_filter_rounded,
        size: 56,
        color: colors.onSecondaryContainer,
      ),
    );
  }
}
