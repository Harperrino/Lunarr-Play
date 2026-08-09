import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_library_service.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_media_card.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_media_shelf.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Jellyfin home: Continue Watching, Next Up, Recently Added and Libraries.
class JellyfinHomeView extends ConsumerWidget {
  const JellyfinHomeView({
    super.key,
    required this.connection,
    required this.onSignOut,
  });

  final JellyfinConnection connection;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(jellyfinHomeDataProvider);
    final images = ref.watch(jellyfinImageServiceProvider);
    final value = home.valueOrNull;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeHeader(
          connection: connection,
          refreshing: home.isLoading,
          onRefresh: () =>
              ref.read(jellyfinHomeDataProvider.notifier).refresh(),
          onSignOut: onSignOut,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch ((home.hasError, value)) {
            (true, null) => _HomeError(
              message: l10n.jellyfinLoadFailed,
              onRetry: () =>
                  ref.read(jellyfinHomeDataProvider.notifier).refresh(),
            ),
            (_, null) => const Center(child: CircularProgressIndicator()),
            (_, final data?) when data.isEmpty => _HomeEmpty(
              onRefresh: () =>
                  ref.read(jellyfinHomeDataProvider.notifier).refresh(),
            ),
            (_, final data?) => _HomeSections(
              data: data,
              images: images,
              connection: connection,
              onOpenLibrary: (library) => jellyfinOpenLibrary(ref, library),
              onOpenItem: (item) => jellyfinOpenDetails(ref, item),
            ),
          },
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.connection,
    required this.refreshing,
    required this.onRefresh,
    required this.onSignOut,
  });

  final JellyfinConnection connection;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connection.baseUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                context.l10n.jellyfinSignedInAs(connection.username),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: context.l10n.jellyfinRefreshTooltip,
          onPressed: refreshing ? null : onRefresh,
          icon: refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: context.l10n.jellyfinSignOut,
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_rounded,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.jellyfinHomeEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.jellyfinHomeEmptySubtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _HomeSections extends StatelessWidget {
  const _HomeSections({
    required this.data,
    required this.images,
    required this.connection,
    required this.onOpenLibrary,
    required this.onOpenItem,
  });

  final JellyfinHomeData data;
  final JellyfinImageService images;
  final JellyfinConnection connection;
  final ValueChanged<JellyfinLibrary> onOpenLibrary;
  final ValueChanged<JellyfinItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (data.resumeItems.isNotEmpty)
          JellyfinMediaShelf(
            title: l10n.jellyfinContinueWatching,
            children: [
              for (final item in data.resumeItems)
                _buildItemCard(context, item),
            ],
          ),
        if (data.resumeItems.isNotEmpty &&
            (data.nextUpItems.isNotEmpty || data.latestItems.isNotEmpty || data.libraries.isNotEmpty))
          const SizedBox(height: 28),
        if (data.nextUpItems.isNotEmpty)
          JellyfinMediaShelf(
            title: l10n.jellyfinNextUp,
            children: [
              for (final item in data.nextUpItems)
                _buildItemCard(context, item),
            ],
          ),
        if (data.nextUpItems.isNotEmpty && (data.latestItems.isNotEmpty || data.libraries.isNotEmpty))
          const SizedBox(height: 28),
        if (data.latestItems.isNotEmpty)
          JellyfinMediaShelf(
            title: l10n.jellyfinRecentlyAdded,
            children: [
              for (final item in data.latestItems)
                _buildItemCard(context, item),
            ],
          ),
        if (data.latestItems.isNotEmpty && data.libraries.isNotEmpty)
          const SizedBox(height: 28),
        if (data.libraries.isNotEmpty)
          JellyfinMediaShelf(
            title: l10n.jellyfinLibraries,
            children: [
              for (final library in data.libraries)
                JellyfinMediaCard(
                  imageUrl: images.posterUrl(
                    connection,
                    itemId: library.id,
                    imageTag: library.imageTag,
                  ),
                  title: library.name,
                  subtitle: _librarySubtitle(l10n, library),
                  semanticLabel: library.name,
                  fallbackIcon: Icons.video_library_rounded,
                  onTap: () => onOpenLibrary(library),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildItemCard(BuildContext context, JellyfinItem item) {
    final l10n = context.l10n;
    final subtitle = switch (item.type) {
      'Episode' => jellyfinSeasonEpisodeLabel(
        l10n,
        season: item.seasonNumber,
        episode: item.episodeNumber,
      ),
      _ => item.productionYear?.toString() ?? '',
    };
    final progress = item.hasResume ? item.resumeFraction : null;

    return JellyfinMediaCard(
      imageUrl: images.posterUrl(
        connection,
        itemId: item.id,
        imageTag: item.primaryImageTag,
      ),
      title: item.name,
      subtitle: subtitle,
      description: item.overview,
      semanticLabel: item.name,
      progress: progress,
      onTap: () => onOpenItem(item),
    );
  }
}

String _librarySubtitle(AppLocalizations l10n, JellyfinLibrary library) {
  return switch (library.collectionType) {
    'movies' => l10n.mediaLibraryMoviesTab,
    'tvshows' => l10n.mediaLibrarySeriesTab,
    _ => '',
  };
}
