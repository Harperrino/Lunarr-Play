import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/theme/catalogue_surface_roles.dart';

const double vodPosterAspectRatio = 2 / 3;

/// Feature-local poster image loading shared by catalogue cards.
///
/// It deliberately owns no feature state. The existing cache dimensions and
/// fallback treatment remain stable while card presentation migrates by screen.
class VodPosterImage extends StatelessWidget {
  const VodPosterImage({
    super.key,
    required this.logoUrl,
    required this.accent,
  });

  final String? logoUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.trim().isEmpty) {
      return _PosterFallback(accent: accent);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = Theme.of(context).colorScheme;
        final roles = CatalogueSurfaceRoles.of(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _cachePixels(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 180,
          dpr,
        );
        final cacheHeight = _cachePixels(
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 180 / vodPosterAspectRatio,
          dpr,
        );

        return CachedNetworkImage(
          imageUrl: logoUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          placeholder: (_, _) => Container(
            color: roles.shimmerBase,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          errorWidget: (_, _, _) => _PosterFallback(accent: accent),
        );
      },
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final roles = CatalogueSurfaceRoles.of(context);
    return Container(
      color: roles.shimmerBase,
      child: Center(
        child: Icon(
          Icons.movie_rounded,
          size: 38,
          color: accent.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

int _cachePixels(double logicalSize, double dpr) {
  return (logicalSize * dpr).ceil().clamp(1, 4096);
}
