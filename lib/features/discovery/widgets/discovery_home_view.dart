import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_navigation_provider.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_category_grid.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_details_pane.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_media_card.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_shelf.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_toolbar.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/widgets/app_shimmer.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';

class DiscoveryHomeView extends ConsumerStatefulWidget {
  const DiscoveryHomeView({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<DiscoveryHomeView> createState() => _DiscoveryHomeViewState();
}

class _DiscoveryHomeViewState extends ConsumerState<DiscoveryHomeView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _homeController = ScrollController();
  final Map<DiscoveryShelfKind, ScrollController> _categoryControllers = {};

  @override
  void initState() {
    super.initState();
    _homeController.addListener(_rememberHomeOffset);
  }

  @override
  void dispose() {
    _homeController
      ..removeListener(_rememberHomeOffset)
      ..dispose();
    for (final controller in _categoryControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _rememberHomeOffset() {
    if (_homeController.hasClients) {
      ref
          .read(discoveryNavigationProvider.notifier)
          .rememberHomeOffset(_homeController.offset);
    }
  }

  ScrollController _categoryController(DiscoveryShelfKind kind) {
    return _categoryControllers.putIfAbsent(kind, () {
      final initial = ref
          .read(discoveryNavigationProvider)
          .categoryScrollOffsets[kind];
      final controller = ScrollController(initialScrollOffset: initial ?? 0);
      controller.addListener(() {
        if (controller.hasClients) {
          ref
              .read(discoveryNavigationProvider.notifier)
              .rememberCategoryOffset(kind, controller.offset);
        }
      });
      return controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(discoverySearchProvider);
    final query = search.valueOrNull?.query ?? '';
    _synchronizeSearchController(query);

    final navigation = ref.watch(discoveryNavigationProvider);
    final current = navigation.current;
    final preferences =
        ref.watch(discoveryPreferencesProvider).valueOrNull ??
        const DiscoveryPreferences();
    final secrets =
        ref.watch(discoverySecretsProvider).valueOrNull ??
        const DiscoverySecrets();
    final tmdbConfigured = secrets.hasTmdbToken;
    final seerrConfigured =
        secrets.hasSeerrApiKey && preferences.seerrEndpoint.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final selected = current.type == DiscoveryDestinationType.details
            ? current.item
            : null;
        final toolbar = DiscoveryToolbar(
          controller: _searchController,
          title: _title(context, navigation, query),
          source: preferences.source,
          tmdbConfigured: tmdbConfigured,
          seerrConfigured: seerrConfigured,
          canGoBack: navigation.canGoBack || query.trim().isNotEmpty,
          onChanged: (value) =>
              ref.read(discoverySearchProvider.notifier).setQuery(value),
          onSubmitted: (value) =>
              ref.read(discoverySearchProvider.notifier).search(value),
          onClear: _clearSearch,
          onBack: _back,
          onHome: _home,
          onRefresh: _refresh,
          onSourceChanged: _switchSource,
          onOpenSettings: widget.onOpenSettings,
        );
        final catalog = _catalog(
          navigation: navigation,
          search: search,
          selected: selected,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              toolbar,
              const SizedBox(height: 16),
              Expanded(
                child: selected == null
                    ? catalog
                    : wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: catalog),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: constraints.maxWidth >= 1320 ? 440 : 380,
                            child: DiscoveryDetailsPane(
                              key: ValueKey(
                                'discovery-wide-details-'
                                '${selected.mediaType.name}-${selected.id}',
                              ),
                              item: selected,
                              onClose: _back,
                            ),
                          ),
                        ],
                      )
                    : DiscoveryDetailsPane(
                        key: ValueKey(
                          'discovery-compact-details-'
                          '${selected.mediaType.name}-${selected.id}',
                        ),
                        item: selected,
                        onClose: _back,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _catalog({
    required DiscoveryNavigationState navigation,
    required AsyncValue<DiscoverySearchState> search,
    required DiscoveryMediaItem? selected,
  }) {
    final searchState = search.valueOrNull;
    if ((searchState?.query.trim().isNotEmpty ?? false)) {
      return _SearchResults(
        state: search,
        onSelect: _openDetails,
        selected: selected,
        onLoadMore: () => ref
            .read(discoverySearchProvider.notifier)
            .search(searchState!.query, append: true),
      );
    }

    final destination =
        navigation.current.type == DiscoveryDestinationType.details &&
            navigation.stack.length > 1
        ? navigation.stack[navigation.stack.length - 2]
        : navigation.current;
    if (destination.type == DiscoveryDestinationType.category) {
      final kind = destination.category!;
      return DiscoveryCategoryGrid(
        kind: kind,
        controller: _categoryController(kind),
        selected: selected,
        onSelect: _openDetails,
      );
    }

    final home = ref.watch(discoveryHomeProvider);
    return home.when(
      data: (feed) => _DiscoveryFeed(
        controller: _homeController,
        feed: feed,
        selected: selected,
        onSelect: _openDetails,
        onShowAll: (kind) =>
            ref.read(discoveryNavigationProvider.notifier).openCategory(kind),
      ),
      loading: () => const _DiscoveryLoadingFeed(),
      error: (error, _) => _DiscoveryFailure(
        error: error,
        source:
            ref.watch(discoveryPreferencesProvider).valueOrNull?.source ??
            DiscoverySource.tmdb,
        onRetry: _refresh,
        onOpenSettings: widget.onOpenSettings,
      ),
    );
  }

  String _title(
    BuildContext context,
    DiscoveryNavigationState navigation,
    String query,
  ) {
    if (navigation.current.type == DiscoveryDestinationType.details) {
      return navigation.current.item!.title;
    }
    if (query.trim().isNotEmpty) return context.l10n.discoverySearchTitle;
    if (navigation.current.type == DiscoveryDestinationType.category) {
      return discoveryShelfTitle(context.l10n, navigation.current.category!);
    }
    return context.l10n.shellTabHomeTitle;
  }

  void _synchronizeSearchController(String query) {
    if (_searchController.text == query) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _searchController.text == query) return;
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
      setState(() {});
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(discoverySearchProvider.notifier).clear();
  }

  void _back() {
    final navigation = ref.read(discoveryNavigationProvider);
    if (navigation.current.type == DiscoveryDestinationType.details) {
      ref.read(discoveryNavigationProvider.notifier).back();
      return;
    }
    final query = ref.read(discoverySearchProvider).valueOrNull?.query ?? '';
    if (query.trim().isNotEmpty) {
      _clearSearch();
      return;
    }
    ref.read(discoveryNavigationProvider.notifier).back();
  }

  void _home() {
    _clearSearch();
    ref.read(discoveryNavigationProvider.notifier).home();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_homeController.hasClients) _homeController.jumpTo(0);
    });
  }

  void _refresh() {
    final search = ref.read(discoverySearchProvider).valueOrNull;
    if (search?.query.trim().isNotEmpty ?? false) {
      ref.read(discoverySearchProvider.notifier).search(search!.query);
      return;
    }
    final destination = ref.read(discoveryNavigationProvider).current;
    if (destination.type == DiscoveryDestinationType.category) {
      ref
          .read(discoveryCategoryProvider(destination.category!).notifier)
          .refresh();
      return;
    }
    ref.read(discoveryHomeProvider.notifier).refresh();
  }

  Future<void> _switchSource(DiscoverySource source) async {
    await ref.read(discoveryPreferencesProvider.notifier).setSource(source);
    if (!mounted) return;
    _home();
    ref.invalidate(discoveryHomeProvider);
    ref.invalidate(discoveryRequestProvider);
  }

  void _openDetails(DiscoveryMediaItem item) {
    ref.read(discoveryNavigationProvider.notifier).openDetails(item);
  }
}

class _DiscoveryFeed extends StatelessWidget {
  const _DiscoveryFeed({
    required this.controller,
    required this.feed,
    required this.selected,
    required this.onSelect,
    required this.onShowAll,
  });

  final ScrollController controller;
  final DiscoveryHomeFeed feed;
  final DiscoveryMediaItem? selected;
  final ValueChanged<DiscoveryMediaItem> onSelect;
  final ValueChanged<DiscoveryShelfKind> onShowAll;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('discovery-home-feed'),
      controller: controller,
      slivers: [
        if (feed.isStale)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSurface(
                level: AppSurfaceLevel.low,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.discoveryStaleData)),
                  ],
                ),
              ),
            ),
          ),
        if (feed.heroItems.isNotEmpty)
          SliverToBoxAdapter(
            child: _DiscoveryHero(
              item: feed.heroItems.first,
              onActivate: () => onSelect(feed.heroItems.first),
            ),
          ),
        for (final shelf in feed.shelves)
          if (shelf.items.isNotEmpty)
            SliverToBoxAdapter(
              child: DiscoveryShelfView(
                shelf: shelf,
                selected: selected,
                onSelect: onSelect,
                onShowAll: () => onShowAll(shelf.kind),
              ),
            ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }
}

class _DiscoveryHero extends StatelessWidget {
  const _DiscoveryHero({required this.item, required this.onActivate});

  final DiscoveryMediaItem item;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shapes = theme.extension<AppShapes>() ?? AppShapes.standard;
    final url = item.backdropUrl ?? item.posterUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Semantics(
        button: true,
        label: context.l10n.discoveryTrendingItemSemantics(item.title),
        child: AppSurface(
          level: AppSurfaceLevel.high,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(shapes.extraLarge),
            child: InkWell(
              onTap: onActivate,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final compact = constraints.maxWidth < 650 || textScale > 1.4;
                  return SizedBox(
                    height: compact
                        ? textScale > 1.4
                              ? 320
                              : constraints.maxWidth * 9 / 16
                        : constraints.maxWidth * 7.5 / 21,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (url != null)
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            memCacheWidth: 1440,
                            errorWidget: (_, _, _) =>
                                ColoredBox(color: colors.tertiaryContainer),
                          )
                        else
                          ColoredBox(color: colors.tertiaryContainer),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.88),
                                Colors.black.withValues(alpha: 0.38),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Padding(
                              padding: EdgeInsets.all(compact ? 16 : 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.discoveryTrendingToday,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (compact
                                                ? theme.textTheme.titleLarge
                                                : theme
                                                      .textTheme
                                                      .headlineMedium)
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                  ),
                                  if (!compact && item.overview.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      item.overview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                  if (item.adult) ...[
                                    const SizedBox(height: 10),
                                    MediaMetadataBadge(
                                      label: context.l10n.discoveryAdultBadge,
                                      icon: Icons.explicit_rounded,
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
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.onSelect,
    required this.selected,
    required this.onLoadMore,
  });

  final AsyncValue<DiscoverySearchState> state;
  final ValueChanged<DiscoveryMediaItem> onSelect;
  final DiscoveryMediaItem? selected;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final value = state.valueOrNull;
    if (value == null || value.query.trim().isEmpty) return const SizedBox();
    if (state.hasError && value.items.isEmpty) {
      return _InlineFailure(error: state.error!, onRetry: onLoadMore);
    }
    if (state.isLoading && value.items.isEmpty) {
      return const _DiscoveryLoadingGrid();
    }
    if (value.items.isEmpty) {
      return Center(child: Text(context.l10n.discoveryNoResults));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 172).floor().clamp(2, 8);
        final highTextScale = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        return GridView.builder(
          key: PageStorageKey<String>('discovery-search-${value.query}'),
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
                  onPressed: state.isLoading ? null : onLoadMore,
                  icon: state.isLoading
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
        );
      },
    );
  }
}

class _DiscoveryFailure extends StatelessWidget {
  const _DiscoveryFailure({
    required this.error,
    required this.source,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final Object error;
  final DiscoverySource source;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final missing =
        error is DiscoveryApiException &&
        (error as DiscoveryApiException).kind ==
            DiscoveryFailureKind.missingConfiguration;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: AppSurface(
          level: AppSurfaceLevel.high,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                missing ? Icons.explore_off_rounded : Icons.cloud_off_rounded,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                missing
                    ? context.l10n.discoverySetupTitle
                    : discoveryFailureText(context.l10n, error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (missing) ...[
                const SizedBox(height: 10),
                Text(
                  source == DiscoverySource.tmdb
                      ? context.l10n.discoverySetupTmdbDescription
                      : context.l10n.discoverySetupSeerrDescription,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  if (!missing)
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.discoveryRetry),
                    ),
                  FilledButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(context.l10n.discoveryOpenSettings),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.error, required this.onRetry});

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

class _DiscoveryLoadingFeed extends StatelessWidget {
  const _DiscoveryLoadingFeed();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    return AppShimmer(
      baseColor: colors.surfaceContainerHigh,
      highlightColor: colors.surfaceContainerHighest,
      child: ListView(
        children: [
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(shapes.extraLarge),
            ),
          ),
          const SizedBox(height: 24),
          for (var row = 0; row < 2; row++) ...[
            Container(
              width: 180,
              height: 24,
              color: colors.surfaceContainerHigh,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, _) =>
                    Container(width: 148, color: colors.surfaceContainerHigh),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _DiscoveryLoadingGrid extends StatelessWidget {
  const _DiscoveryLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppShimmer(
      baseColor: colors.surfaceContainerHigh,
      highlightColor: colors.surfaceContainerHighest,
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.count(
          crossAxisCount: (constraints.maxWidth / 172).floor().clamp(2, 8),
          crossAxisSpacing: 14,
          mainAxisSpacing: 18,
          children: [
            for (var item = 0; item < 10; item++)
              ColoredBox(color: colors.surfaceContainerHigh),
          ],
        ),
      ),
    );
  }
}
