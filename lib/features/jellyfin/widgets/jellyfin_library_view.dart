import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_media_card.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Poster-grid columns for the current content width.
///
/// Scales continuously at 1080 px, 1440 px and 4K window widths without fixed
/// column counts.
int jellyfinGridColumnsFor(
  double maxWidth, {
  double minCardWidth = 180,
  double gap = 14,
}) {
  if (maxWidth <= 0) return 1;
  final columns = ((maxWidth + gap) / (minCardWidth + gap)).floor();
  return columns.clamp(1, 12);
}

/// Items of one Jellyfin library as an adaptive poster grid.
class JellyfinLibraryView extends ConsumerWidget {
  const JellyfinLibraryView({
    super.key,
    required this.connection,
    required this.library,
  });

  final JellyfinConnection connection;
  final JellyfinLibrary library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(jellyfinLibraryItemsProvider(library.id));
    final images = ref.watch(jellyfinImageServiceProvider);
    final l10n = context.l10n;
    final value = items.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.commonBackTooltip,
              onPressed: () => jellyfinGoBack(ref),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                library.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (value != null)
              Text(
                l10n.jellyfinItemsCount(value.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            IconButton(
              tooltip: l10n.jellyfinRefreshTooltip,
              onPressed: items.isLoading
                  ? null
                  : () =>
                        ref
                            .read(jellyfinLibraryItemsProvider(library.id).notifier)
                            .refresh(),
              icon: items.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch ((items.hasError, value)) {
            (true, null) => _LibraryError(
              message: l10n.jellyfinLoadFailed,
              onRetry: () => ref
                  .read(jellyfinLibraryItemsProvider(library.id).notifier)
                  .refresh(),
            ),
            (_, null) =>
              const Center(child: CircularProgressIndicator()),
            (_, final data?) when data.isEmpty => _LibraryEmpty(
              onRefresh: () => ref
                  .read(jellyfinLibraryItemsProvider(library.id).notifier)
                  .refresh(),
            ),
            (_, final data?) => LayoutBuilder(
              builder: (context, constraints) {
                final columns = jellyfinGridColumnsFor(constraints.maxWidth);
                final cardWidth =
                    (constraints.maxWidth - 14 * (columns - 1)) / columns;

                return GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 22,
                    mainAxisExtent: cardWidth * 1.5 + 64,
                  ),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return JellyfinMediaCard(
                      imageUrl: images.posterUrl(
                        connection,
                        itemId: item.id,
                        imageTag: item.primaryImageTag,
                      ),
                      title: item.name,
                      subtitle: item.productionYear?.toString() ?? '',
                      semanticLabel: item.name,
                      progress: item.hasResume ? item.resumeFraction : null,
                      onTap: () => jellyfinOpenDetails(ref, item),
                    );
                  },
                );
              },
            ),
          },
        ),
      ],
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty({required this.onRefresh});

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
            context.l10n.jellyfinLibraryEmpty,
            style: Theme.of(context).textTheme.titleMedium,
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
