import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_trailer_launcher.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/widgets/app_shimmer.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';

class DiscoveryDetailsPane extends ConsumerStatefulWidget {
  const DiscoveryDetailsPane({
    super.key,
    required this.item,
    this.onClose,
    this.pageMode = false,
  });

  final DiscoveryMediaItem item;
  final VoidCallback? onClose;
  final bool pageMode;

  @override
  ConsumerState<DiscoveryDetailsPane> createState() =>
      _DiscoveryDetailsPaneState();
}

class _DiscoveryDetailsPaneState extends ConsumerState<DiscoveryDetailsPane> {
  DiscoveryMediaItem? _requestResult;
  bool _requesting = false;
  final FocusNode _trailerFocusNode = FocusNode();

  @override
  void dispose() {
    _trailerFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DiscoveryDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.mediaType != widget.item.mediaType) {
      _requestResult = null;
      _requesting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(discoveryDetailsProvider(widget.item));
    final partial = _requestResult ?? widget.item;
    final child = details.when(
      data: (item) => _body(_requestResult ?? item),
      loading: () => _body(partial, loading: true),
      error: (error, _) => _body(partial, detailsError: error),
    );

    if (widget.pageMode) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.l10n.discoveryDetailsCloseTooltip,
            onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(widget.item.title),
        ),
        body: SafeArea(child: child),
      );
    }
    return child;
  }

  Widget _body(
    DiscoveryMediaItem item, {
    bool loading = false,
    Object? detailsError,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shapes = theme.extension<AppShapes>() ?? AppShapes.standard;
    final source =
        ref.watch(discoveryPreferencesProvider).valueOrNull?.source ??
        DiscoverySource.tmdb;
    final status = discoveryStatusText(context.l10n, item);

    return AppSurface(
      key: ValueKey('discovery-details-${item.mediaType.name}-${item.id}'),
      level: AppSurfaceLevel.high,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(shapes.extraLarge),
        child: CustomScrollView(
          key: PageStorageKey<String>(
            'discovery-details-scroll-${item.mediaType.name}-${item.id}',
          ),
          slivers: [
            SliverToBoxAdapter(child: _artwork(item)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              sliver: SliverList.list(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      if (widget.onClose != null && !widget.pageMode)
                        IconButton(
                          tooltip: context.l10n.discoveryDetailsCloseTooltip,
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MediaMetadataBadge(
                        label: discoveryMediaTypeText(
                          context.l10n,
                          item.mediaType,
                        ),
                      ),
                      if (item.releaseDate case final release?)
                        MediaMetadataBadge(
                          label: context.l10n.discoveryReleaseYear(
                            release.year,
                          ),
                          icon: Icons.calendar_month_rounded,
                        ),
                      if (item.voteAverage case final rating?)
                        MediaMetadataBadge(
                          label: context.l10n.discoveryRating(
                            rating.toStringAsFixed(1),
                          ),
                          icon: Icons.star_rounded,
                        ),
                      if (item.runtimeMinutes case final runtime?)
                        MediaMetadataBadge(
                          label: context.l10n.discoveryRuntimeMinutes(runtime),
                          icon: Icons.schedule_rounded,
                        ),
                      if (item.adult)
                        MediaMetadataBadge(
                          label: context.l10n.discoveryAdultBadge,
                          icon: Icons.explicit_rounded,
                        ),
                      if (status != null)
                        MediaMetadataBadge(
                          label: status,
                          icon:
                              item.availability ==
                                  DiscoveryAvailability.available
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                        ),
                    ],
                  ),
                  if (item.genres.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      item.genres.join(' · '),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.trailers.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Semantics(
                          link: true,
                          child: FilledButton.tonalIcon(
                            focusNode: _trailerFocusNode,
                            onPressed: () => _openTrailer(item.trailers.first),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(context.l10n.discoveryOpenTrailer),
                          ),
                        ),
                        if (item.trailers.length > 1)
                          PopupMenuButton<DiscoveryTrailer>(
                            tooltip: context.l10n.discoveryMoreTrailers,
                            onSelected: _openTrailer,
                            itemBuilder: (context) => item.trailers
                                .skip(1)
                                .map(
                                  (trailer) => PopupMenuItem<DiscoveryTrailer>(
                                    value: trailer,
                                    child: Text(
                                      trailer.title.trim().isEmpty
                                          ? context.l10n.discoveryOpenTrailer
                                          : trailer.title,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            child: Chip(
                              avatar: const Icon(Icons.video_library_rounded),
                              label: Text(context.l10n.discoveryMoreTrailers),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    item.overview.trim().isEmpty
                        ? context.l10n.discoveryOverviewUnavailable
                        : item.overview,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (detailsError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      discoveryFailureText(context.l10n, detailsError),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => ref.invalidate(
                          discoveryDetailsProvider(widget.item),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.l10n.discoveryRetry),
                      ),
                    ),
                  ],
                  if (source == DiscoverySource.seerr) ...[
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: item.canRequest && !_requesting
                            ? () => _request(item)
                            : null,
                        icon: _requesting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_to_queue_rounded),
                        label: Text(status ?? context.l10n.discoveryRequest),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTrailer(DiscoveryTrailer trailer) async {
    await ref
        .read(discoveryTrailerLauncherProvider)
        .open(context, trailer: trailer);
    if (mounted) _trailerFocusNode.requestFocus();
  }

  Widget _artwork(DiscoveryMediaItem item) {
    final colors = Theme.of(context).colorScheme;
    final url = item.backdropUrl ?? item.posterUrl;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: url == null
          ? _artworkFallback(item)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 960,
              placeholder: (_, _) => AppShimmer(
                baseColor: colors.surfaceContainerHigh,
                highlightColor: colors.surfaceContainerHighest,
                child: ColoredBox(color: colors.surfaceContainerHigh),
              ),
              errorWidget: (_, _, _) => _artworkFallback(item),
            ),
    );
  }

  Widget _artworkFallback(DiscoveryMediaItem item) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.tertiaryContainer,
      child: Center(
        child: Icon(
          item.mediaType == DiscoveryMediaType.movie
              ? Icons.movie_rounded
              : Icons.tv_rounded,
          size: 56,
          color: colors.onTertiaryContainer,
        ),
      ),
    );
  }

  Future<void> _request(DiscoveryMediaItem item) async {
    final choice = await showDialog<_RequestChoice>(
      context: context,
      builder: (context) => _SeerrRequestDialog(item: item),
    );
    if (choice == null || !mounted) return;
    setState(() => _requesting = true);
    try {
      final result = await ref
          .read(discoveryRequestProvider.notifier)
          .request(item, seasons: choice.seasons);
      if (!mounted || result == null) return;
      setState(() => _requestResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.discoveryRequestSuccess)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(discoveryFailureText(context.l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}

class _RequestChoice {
  const _RequestChoice(this.seasons);

  final List<int>? seasons;
}

class _SeerrRequestDialog extends StatefulWidget {
  const _SeerrRequestDialog({required this.item});

  final DiscoveryMediaItem item;

  @override
  State<_SeerrRequestDialog> createState() => _SeerrRequestDialogState();
}

class _SeerrRequestDialogState extends State<_SeerrRequestDialog> {
  bool _allSeasons = true;
  final Set<int> _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final isSeries = widget.item.mediaType == DiscoveryMediaType.tv;
    final seasons =
        widget.item.seasons
            .where((season) => season.number >= 0)
            .toList(growable: false)
          ..sort((left, right) => left.number.compareTo(right.number));
    final canSubmit =
        !isSeries || seasons.isEmpty || _allSeasons || _selected.isNotEmpty;

    return AlertDialog(
      title: Text(context.l10n.discoveryRequestTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.discoveryRequestMessage(widget.item.title)),
              if (isSeries && seasons.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.l10n.discoveryRequestSelectSeasons,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.discoveryRequestAllSeasons),
                  value: _allSeasons,
                  onChanged: (value) => setState(() {
                    _allSeasons = value ?? false;
                    if (_allSeasons) _selected.clear();
                  }),
                ),
                if (!_allSeasons)
                  for (final season in seasons)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        season.name.trim().isEmpty
                            ? context.l10n.discoveryRequestSeason(season.number)
                            : season.name,
                      ),
                      subtitle: season.episodeCount > 0
                          ? Text(
                              context.l10n.discoveryEpisodeCount(
                                season.episodeCount,
                              ),
                            )
                          : null,
                      value: _selected.contains(season.number),
                      onChanged: (value) => setState(() {
                        value == true
                            ? _selected.add(season.number)
                            : _selected.remove(season.number);
                      }),
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.discoveryRequestCancel),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () => Navigator.of(context).pop(
                  _RequestChoice(
                    isSeries && !_allSeasons
                        ? (_selected.toList(growable: false)..sort())
                        : null,
                  ),
                )
              : null,
          child: Text(context.l10n.discoveryRequestConfirm),
        ),
      ],
    );
  }
}
