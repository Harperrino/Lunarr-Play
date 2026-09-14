import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_shimmer.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

class DiscoveryMediaCard extends StatelessWidget {
  const DiscoveryMediaCard({
    super.key,
    required this.item,
    required this.onActivate,
    this.selected = false,
    this.width = 148,
  });

  final DiscoveryMediaItem item;
  final VoidCallback onActivate;
  final bool selected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final year = item.releaseDate?.year;
    final metadata = <String>[
      discoveryMediaTypeText(l10n, item.mediaType),
      if (year != null) '$year',
      if (item.voteAverage case final rating?) rating.toStringAsFixed(1),
    ].join(' · ');
    final semanticLabel = item.adult
        ? '${item.title}, $metadata, ${l10n.discoveryAdultBadge}'
        : '${item.title}, $metadata';

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MediaPosterFrame(
            semanticLabel: semanticLabel,
            onActivate: onActivate,
            isSelected: selected,
            poster: _DiscoveryPoster(item: item),
          ),
          const SizedBox(height: 8),
          MediaMetadataRow(
            title: item.title,
            subtitle: metadata,
            badges: item.adult
                ? <MediaMetadataBadge>[
                    MediaMetadataBadge(
                      label: l10n.discoveryAdultBadge,
                      icon: Icons.explicit_rounded,
                    ),
                  ]
                : const <MediaMetadataBadge>[],
          ),
        ],
      ),
    );
  }
}

class _DiscoveryPoster extends StatelessWidget {
  const _DiscoveryPoster({required this.item});

  final DiscoveryMediaItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = item.posterUrl;
    if (url == null || url.isEmpty) return _fallback(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 360,
      fadeInDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      placeholder: (_, _) => AppShimmer(
        baseColor: colors.surfaceContainerHigh,
        highlightColor: colors.surfaceContainerHighest,
        child: ColoredBox(color: colors.surfaceContainerHigh),
      ),
      errorWidget: (_, _, _) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.tertiaryContainer,
      child: Center(
        child: Icon(
          item.mediaType == DiscoveryMediaType.movie
              ? Icons.movie_rounded
              : Icons.tv_rounded,
          size: 38,
          color: colors.onTertiaryContainer,
        ),
      ),
    );
  }
}
