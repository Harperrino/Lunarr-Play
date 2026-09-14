import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_media_card.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

class DiscoveryCategoryGrid extends ConsumerWidget {
  const DiscoveryCategoryGrid({
    super.key,
    required this.kind,
    required this.controller,
    required this.onSelect,
    this.selected,
  });

  final DiscoveryShelfKind kind;
  final ScrollController controller;
  final DiscoveryMediaItem? selected;
  final ValueChanged<DiscoveryMediaItem> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(discoveryCategoryProvider(kind));
    final value = asyncState.valueOrNull;
    if (asyncState.hasError && (value == null || value.items.isEmpty)) {
      return _CategoryFailure(
        error: asyncState.error!,
        onRetry: () =>
            ref.read(discoveryCategoryProvider(kind).notifier).refresh(),
      );
    }
    if (asyncState.isLoading && (value == null || value.items.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (value == null || value.items.isEmpty) {
      return Center(child: Text(context.l10n.discoveryNoResults));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 172).floor().clamp(2, 8);
        final highTextScale = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(discoveryCategoryProvider(kind).notifier).refresh(),
          child: GridView.builder(
            key: PageStorageKey<String>('discovery-category-${kind.name}'),
            controller: controller,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
              childAspectRatio: highTextScale ? 0.42 : 0.52,
            ),
            itemCount: value.items.length + (value.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == value.items.length) {
                return Center(
                  child: FilledButton.tonalIcon(
                    onPressed: asyncState.isLoading
                        ? null
                        : () => ref
                              .read(discoveryCategoryProvider(kind).notifier)
                              .loadMore(),
                    icon: asyncState.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(context.l10n.discoveryLoadMore),
                  ),
                );
              }
              final item = value.items[index];
              return DiscoveryMediaCard(
                item: item,
                width: double.infinity,
                selected:
                    selected?.id == item.id &&
                    selected?.mediaType == item.mediaType,
                onActivate: () => onSelect(item),
              );
            },
          ),
        );
      },
    );
  }
}

class _CategoryFailure extends StatelessWidget {
  const _CategoryFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(discoveryFailureText(context.l10n, error)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.l10n.discoveryRetry),
        ),
      ],
    ),
  );
}
