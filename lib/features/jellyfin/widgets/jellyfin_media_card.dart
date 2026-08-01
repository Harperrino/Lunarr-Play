import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    this.progress,
    this.fallbackIcon = Icons.movie_rounded,
    this.onTap,
  });

  final String? imageUrl;
  final String title;
  final String semanticLabel;
  final String? subtitle;
  final double? progress;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaPosterFrame(
          semanticLabel: semanticLabel,
          onActivate: onTap,
          poster: _JellyfinPosterImage(
            imageUrl: imageUrl,
            fallbackIcon: fallbackIcon,
          ),
        ),
        const SizedBox(height: 8),
        MediaMetadataRow(title: title, subtitle: subtitle),
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
  }
}

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
        final cacheHeight = _cachePixels(
          constraints.maxHeight.isFinite ? constraints.maxHeight : 225,
          dpr,
        );

        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
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
