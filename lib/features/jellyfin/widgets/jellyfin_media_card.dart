import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

/// Poster card used across the Jellyfin home, library and detail surfaces.
///
/// Pure presentation: the caller resolves [imageUrl] through
/// `JellyfinImageService` and computes [subtitle] and [progress].
class JellyfinMediaCard extends StatelessWidget {
  const JellyfinMediaCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.semanticLabel,
    this.subtitle,
    this.description,
    this.progress,
    this.fallbackIcon = Icons.movie_rounded,
    this.onTap,
  });

  final String? imageUrl;
  final String title;
  final String semanticLabel;
  final String? subtitle;
  final String? description;
  final double? progress;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  static const posterAspectRatio = 2 / 3;

  static double posterHeightFor(double cardWidth) =>
      cardWidth / posterAspectRatio;

  /// Reserved card extent for a 2:3 poster, metadata, two-line overview and
  /// optional progress indicator. Grid and shelf parents use this same value
  /// so the text block cannot collide with the next row.
  static double extentFor(double cardWidth) =>
      posterHeightFor(cardWidth) + jellyfinMediaCardInfoExtent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final trimmedDescription = description?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasFiniteWidth = constraints.maxWidth.isFinite;
        final poster = MediaPosterFrame(
          semanticLabel: semanticLabel,
          onActivate: onTap,
          poster: _JellyfinPosterImage(
            imageUrl: imageUrl,
            fallbackIcon: fallbackIcon,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasFiniteWidth)
              SizedBox(
                height: posterHeightFor(constraints.maxWidth),
                child: poster,
              )
            else
              poster,
            const SizedBox(height: 8),
            MediaMetadataRow(title: title, subtitle: subtitle),
            if (trimmedDescription != null &&
                trimmedDescription.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                trimmedDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.25),
              ),
            ],
            if (progress != null && progress! > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: colors.surfaceContainerHigh,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Fixed space below the poster for card text and optional progress.
const double jellyfinMediaCardInfoExtent = 112;

double jellyfinMediaCardExtentFor(double cardWidth) =>
    JellyfinMediaCard.extentFor(cardWidth);

class _JellyfinPosterImage extends StatelessWidget {
  const _JellyfinPosterImage({
    required this.imageUrl,
    required this.fallbackIcon,
  });

  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return _fallback(colors, Icons.image_not_supported_rounded);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _cachePixels(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 150,
          dpr,
        );
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          placeholder: (_, _) => Container(
            color: colors.surfaceContainerHigh,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, _, _) => _fallback(colors, fallbackIcon),
        );
      },
    );
  }

  Widget _fallback(ColorScheme colors, IconData icon) {
    return Container(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: Icon(icon, size: 34, color: colors.onSurfaceVariant),
      ),
    );
  }
}

int _cachePixels(double logicalSize, double dpr) {
  return (logicalSize * dpr).ceil().clamp(1, 4096);
}
