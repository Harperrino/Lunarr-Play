import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/search/search_models.dart';
import 'package:m3uxtream_player/shared/layout/live_layout_geometry.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';
import 'package:m3uxtream_player/app/composition/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/app/services/category_search_navigation.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

Color globalSearchHintColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// Central search field for the app header - visible on every tab.
class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key, this.width = 720});

  static const fieldHeight = LiveLayoutMetrics.searchFieldHeight;

  final double width;

  @override
  ConsumerState<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  static const _overlayMaxWidth = 480.0;
  static const _overlayViewportMargin = 12.0;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final OverlayPortalController _overlayController;
  final LayerLink _searchLayerLink = LayerLink();
  final GlobalKey _targetKey = GlobalKey(debugLabel: 'GlobalSearchTarget');
  final Object _tapRegionGroup = Object();
  bool _syncingFromProvider = false;
  bool _overlayDismissed = false;
  double _overlayOffsetDx = 0;
  bool _overlayOffsetSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onLocalTextChanged);
    _focusNode = FocusNode(
      debugLabel: 'GlobalCategorySearch',
      onKeyEvent: _handleKeyEvent,
    );
    _focusNode.addListener(_onFocusChanged);
    _overlayController = OverlayPortalController()..show();
  }

  @override
  void dispose() {
    _controller.removeListener(_onLocalTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(globalSearchQueryProvider);
    final session = ref.watch(searchOverlaySessionProvider);
    final filter = ref.watch(searchOverlayFilterProvider);
    final results = ref.watch(globalSearchResultsProvider);
    final resultState = ref.watch(searchResultsAsyncProvider);
    final items = results.itemsFor(filter);
    final showIndexStatus = session.isOpen || items.isNotEmpty;
    final indexState = showIndexStatus
        ? ref.watch(searchIndexBuildStateProvider).valueOrNull
        : null;

    if (!_syncingFromProvider && _controller.text != query) {
      _applyProviderQuery(query);
    }
    if (_focusNode.hasFocus &&
        query.trim().isNotEmpty &&
        !session.isOpen &&
        !_overlayDismissed) {
      _scheduleOverlayOpen();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(0.0, widget.width).toDouble()
            : widget.width;
        final colors = Theme.of(context).colorScheme;
        final status = Theme.of(context).extension<AppStatusColors>();

        final searchBar = SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          hintText: context.l10n.globalSearchHint,
          onChanged: _onTextChanged,
          onSubmitted: _onSubmitted,
          textInputAction: TextInputAction.search,
          onTap: _onSearchBarTap,
          constraints: const BoxConstraints(
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: GlobalSearchField.fieldHeight,
            maxHeight: GlobalSearchField.fieldHeight,
          ),
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
          elevation: const WidgetStatePropertyAll(AppElevation.level0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colors.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return colors.primary.withValues(alpha: 0.08);
            }
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return BorderSide(
                color: status?.focus ?? colors.primary,
                width: 2,
              );
            }
            return BorderSide.none;
          }),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          padding: const WidgetStatePropertyAll(EdgeInsets.only(left: 8)),
          textStyle: WidgetStatePropertyAll(TextStyle(color: colors.onSurface)),
          hintStyle: WidgetStatePropertyAll(
            TextStyle(color: globalSearchHintColor(context)),
          ),
          leading: SizedBox(
            width: 40,
            height: 48,
            child: Icon(Icons.search_rounded, size: 20, color: colors.primary),
          ),
          trailing: [
            if (showIndexStatus && indexState?.isBuilding == true)
              _SearchIndexProgressAction(state: indexState!),
            if (showIndexStatus && (indexState?.failedCount ?? 0) > 0)
              _SearchIndexRetryAction(
                state: indexState!,
                onRetry: () => unawaited(_retrySearchIndex(ref)),
              ),
            if (query.isNotEmpty)
              IconButton(
                onPressed: _clear,
                tooltip: context.l10n.globalSearchClearTooltip,
                icon: const Icon(Icons.close_rounded, size: 18),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.zero,
                color: colors.onSurfaceVariant,
              ),
          ],
        );

        return TapRegion(
          groupId: _tapRegionGroup,
          onTapOutside: (_) => _closeOverlay(),
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: (overlayContext) {
              if (!session.isOpen || query.trim().isEmpty) {
                return const SizedBox.shrink();
              }

              final viewport = MediaQuery.sizeOf(overlayContext);
              final overlayWidth = _boundedOverlayWidth(
                effectiveWidth,
                viewport.width,
              );
              _scheduleOverlayOffsetSync();
              final maxHeight = math.max(
                64.0,
                viewport.height - GlobalSearchField.fieldHeight - 32,
              );
              final highlightedIndex = session.highlightedIndex
                  .clamp(0, math.max(0, items.length - 1))
                  .toInt();

              return CompositedTransformFollower(
                link: _searchLayerLink,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: Offset(_overlayOffsetDx, 8),
                showWhenUnlinked: false,
                // The overlay theatre hands down tight full-size constraints;
                // the Align shrink-wraps the follower child to its real size
                // so the surface does not span the whole window.
                child: Align(
                  alignment: Alignment.topLeft,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: SizedBox(
                    width: overlayWidth,
                    child: TapRegion(
                      groupId: _tapRegionGroup,
                      child: _GlobalSearchOverlay(
                        maxHeight: maxHeight,
                        filter: filter,
                        items: items,
                        resultState: resultState,
                        highlightedIndex: highlightedIndex,
                        onFilterChanged: _setFilter,
                        onHighlighted: _setHighlighted,
                        onSelected: _selectItem,
                        onClosed: _closeOverlay,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Semantics(
              textField: true,
              label: context.l10n.globalSearchSemanticsLabel,
              child: FocusTraversalGroup(
                policy: _SearchBarTraversalPolicy(),
                child: CompositedTransformTarget(
                  key: _targetKey,
                  link: _searchLayerLink,
                  child: SizedBox(
                    width: effectiveWidth,
                    height: GlobalSearchField.fieldHeight,
                    child: searchBar,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus && _controller.text.trim().isNotEmpty) {
      _overlayDismissed = false;
      _openOverlay();
    }
  }

  /// Overlay width contract: at most the search-bar width, never wider than
  /// 480 dp, and always 24 dp narrower than the viewport.
  static double _boundedOverlayWidth(double barWidth, double viewportWidth) {
    return math
        .min(
          math.min(barWidth, _overlayMaxWidth),
          math.max(0.0, viewportWidth - 2 * _overlayViewportMargin),
        )
        .toDouble();
  }

  /// Clamps the horizontally link-anchored overlay so it keeps at least
  /// 12 dp distance to both window edges. The vertical anchoring stays fully
  /// owned by the [LayerLink]; topbar width changes and window resizes only
  /// re-run this clamp, never move the anchor itself.
  void _scheduleOverlayOffsetSync() {
    if (_overlayOffsetSyncScheduled) return;
    _overlayOffsetSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayOffsetSyncScheduled = false;
      if (!mounted) return;
      final targetContext = _targetKey.currentContext;
      if (targetContext == null) return;
      final renderObject = targetContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;

      final viewportWidth = MediaQuery.sizeOf(context).width;
      final overlayWidth = _boundedOverlayWidth(
        renderObject.size.width,
        viewportWidth,
      );
      final barLeft = renderObject.localToGlobal(Offset.zero).dx;
      final maxLeft = math.max(
        _overlayViewportMargin,
        viewportWidth - _overlayViewportMargin - overlayWidth,
      );
      final clampedLeft = barLeft
          .clamp(_overlayViewportMargin, maxLeft)
          .toDouble();
      final offsetDx = clampedLeft - barLeft;
      if ((offsetDx - _overlayOffsetDx).abs() > 0.5) {
        setState(() => _overlayOffsetDx = offsetDx);
      }
    });
  }

  void _onSearchBarTap() {
    _overlayDismissed = false;
    if (_controller.text.trim().isNotEmpty) _openOverlay();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _closeOverlay();
      return KeyEventResult.handled;
    }

    final filter = ref.read(searchOverlayFilterProvider);
    final results = ref.read(globalSearchResultsProvider);
    final items = results.itemsFor(filter);
    if (!_focusNode.hasFocus) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setFilter(_previousFilter(filter));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setFilter(_nextFilter(filter));
      return KeyEventResult.handled;
    }
    if (items.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final highlighted = ref
          .read(searchOverlaySessionProvider)
          .highlightedIndex;
      _setHighlighted((highlighted + 1) % items.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final highlighted = ref
          .read(searchOverlaySessionProvider)
          .highlightedIndex;
      _setHighlighted((highlighted - 1 + items.length) % items.length);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final highlighted = ref
          .read(searchOverlaySessionProvider)
          .highlightedIndex;
      _selectItem(items[highlighted.clamp(0, items.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scheduleOverlayOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus || _overlayDismissed) return;
      if (_controller.text.trim().isNotEmpty) _openOverlay();
    });
  }

  void _openOverlay() {
    if (_controller.text.trim().isEmpty) return;
    _overlayDismissed = false;
    final session = ref.read(searchOverlaySessionProvider);
    if (session.isOpen) return;
    ref.read(searchOverlaySessionProvider.notifier).state = session.copyWith(
      isOpen: true,
      highlightedIndex: 0,
    );
  }

  void _closeOverlay() {
    _overlayDismissed = true;
    final session = ref.read(searchOverlaySessionProvider);
    if (!session.isOpen) return;
    ref.read(searchOverlaySessionProvider.notifier).state = session.copyWith(
      isOpen: false,
      highlightedIndex: 0,
    );
  }

  void _setHighlighted(int index) {
    final session = ref.read(searchOverlaySessionProvider);
    if (session.highlightedIndex == index) return;
    ref.read(searchOverlaySessionProvider.notifier).state = session.copyWith(
      highlightedIndex: index,
    );
  }

  void _setFilter(SearchOverlayFilter filter) {
    if (ref.read(searchOverlayFilterProvider) == filter) return;
    ref.read(searchOverlayFilterProvider.notifier).state = filter;
    final session = ref.read(searchOverlaySessionProvider);
    ref.read(searchOverlaySessionProvider.notifier).state = session.copyWith(
      highlightedIndex: 0,
    );
  }

  void _onLocalTextChanged() {
    if (_syncingFromProvider) return;
    final next = _controller.text;
    if (ref.read(globalSearchQueryProvider) == next) return;
    _overlayDismissed = false;
    ref.read(globalSearchQueryProvider.notifier).state = next;
    if (next.trim().isEmpty) {
      _closeOverlay();
    } else if (_focusNode.hasFocus) {
      _openOverlay();
    }
  }

  void _onTextChanged(String value) {
    if (_syncingFromProvider) return;
    _overlayDismissed = false;
    if (ref.read(globalSearchQueryProvider) != value) {
      ref.read(globalSearchQueryProvider.notifier).state = value;
    }
    if (value.trim().isEmpty) {
      _closeOverlay();
    } else if (_focusNode.hasFocus) {
      _openOverlay();
    }
  }

  void _onSubmitted(String value) {
    _onTextChanged(value);
    final items = ref
        .read(globalSearchResultsProvider)
        .itemsFor(ref.read(searchOverlayFilterProvider));
    if (items.isEmpty) return;
    final highlighted = ref.read(searchOverlaySessionProvider).highlightedIndex;
    _selectItem(items[highlighted.clamp(0, items.length - 1)]);
  }

  void _selectItem(GlobalSearchResultItem item) {
    final navigation = ref.read(categorySearchNavigationControllerProvider);
    if (item.channel case final channel?) {
      unawaited(navigation.openChannel(channel));
    } else if (item.category case final category?) {
      navigation.open(category);
    }
    _closeOverlay();
  }

  void _applyProviderQuery(String query) {
    _syncingFromProvider = true;
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    _syncingFromProvider = false;
    if (query.trim().isEmpty) {
      _scheduleOverlayClose();
    } else if (_focusNode.hasFocus) {
      _overlayDismissed = false;
      _scheduleOverlayOpen();
    }
  }

  void _scheduleOverlayClose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(globalSearchQueryProvider).trim().isNotEmpty) {
        return;
      }
      _closeOverlay();
    });
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    ref.read(globalSearchQueryProvider.notifier).state = '';
    _closeOverlay();
  }
}

class _GlobalSearchOverlay extends ConsumerWidget {
  const _GlobalSearchOverlay({
    required this.maxHeight,
    required this.filter,
    required this.items,
    required this.resultState,
    required this.highlightedIndex,
    required this.onFilterChanged,
    required this.onHighlighted,
    required this.onSelected,
    required this.onClosed,
  });

  final double maxHeight;
  final SearchOverlayFilter filter;
  final List<GlobalSearchResultItem> items;
  final AsyncValue<GlobalSearchResults> resultState;
  final int highlightedIndex;
  final ValueChanged<SearchOverlayFilter> onFilterChanged;
  final ValueChanged<int> onHighlighted;
  final ValueChanged<GlobalSearchResultItem> onSelected;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final indexState = ref.watch(searchIndexBuildStateProvider).valueOrNull;
    final epgAsync = items.any((item) => item.isChannel)
        ? ref.watch(searchEpgLinesProvider)
        : const AsyncValue.data(<int, SearchEpgLine>{});

    final Widget resultBody;
    if (resultState.hasError) {
      resultBody = SizedBox(
        key: const ValueKey('global-search-error-state'),
        height: 72,
        child: Center(child: Text(context.l10n.globalSearchUnavailable)),
      );
    } else if (indexState != null && indexState.isBuilding && items.isEmpty) {
      resultBody = SizedBox(
        key: const ValueKey('global-search-index-progress-state'),
        height: 72,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.globalSearchIndexBuildingProgress(
                  indexState.readyCount,
                  indexState.total,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (resultState.isLoading &&
        !resultState.hasValue &&
        items.isEmpty) {
      resultBody = SizedBox(
        key: const ValueKey('global-search-loading-state'),
        height: 72,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(context.l10n.globalSearchLoading),
            ],
          ),
        ),
      );
    } else if (items.isEmpty) {
      resultBody = SizedBox(
        key: const ValueKey('global-search-empty-state'),
        height: 72,
        child: Center(child: Text(context.l10n.globalSearchNoResults)),
      );
    } else {
      resultBody = ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final item = items[index];
          final highlighted = index == highlightedIndex;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => onHighlighted(index),
            child: Semantics(
              container: true,
              button: true,
              selected: highlighted,
              label: _itemLabel(context, item),
              hint: context.l10n.globalSearchOpenHint,
              onTap: () => onSelected(item),
              child: Material(
                color: highlighted
                    ? colors.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey(_itemKey(item)),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(item),
                  child: _SearchResultRow(
                    item: item,
                    highlighted: highlighted,
                    epgAsync: epgAsync,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Focus(
      onKeyEvent: (_, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            (event is KeyDownEvent || event is KeyRepeatEvent)) {
          onClosed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AppOverlaySurface(
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<SearchOverlayFilter>(
                segments: [
                  for (final filter in SearchOverlayFilter.values)
                    ButtonSegment<SearchOverlayFilter>(
                      value: filter,
                      label: Text(_searchOverlayFilterLabel(context, filter)),
                    ),
                ],
                selected: {filter},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) onFilterChanged(selection.first);
                },
              ),
              if (indexState != null &&
                  (indexState.isBuilding || indexState.failedCount > 0)) ...[
                const SizedBox(height: 6),
                _SearchIndexStatusBanner(
                  state: indexState,
                  onRetry: indexState.failedCount > 0
                      ? () => unawaited(_retrySearchIndex(ref))
                      : null,
                ),
              ],
              const SizedBox(height: 8),
              Flexible(child: resultBody),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _retrySearchIndex(WidgetRef ref) async {
  try {
    await ref.read(searchIndexRepositoryProvider).retryIncompleteIndexes();
  } catch (_) {
    // The persisted per-playlist failure state remains visible. A retry
    // action must not turn a recoverable catalogue issue into an overlay
    // exception.
  }
}

class _SearchIndexProgressAction extends StatelessWidget {
  const _SearchIndexProgressAction({required this.state});

  final SearchIndexBuildState state;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.globalSearchIndexProgressSemantics(
      state.readyCount,
      state.total,
    );
    return Semantics(
      liveRegion: true,
      label: label,
      child: Tooltip(
        message: label,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchIndexRetryAction extends StatelessWidget {
  const _SearchIndexRetryAction({required this.state, required this.onRetry});

  final SearchIndexBuildState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.globalSearchIndexRetrySemantics(
      state.failedCount,
    );
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: IconButton(
          onPressed: onRetry,
          tooltip: null,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20),
              const SizedBox(width: 2),
              Text(state.failedCount.toString()),
            ],
          ),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _SearchIndexStatusBanner extends StatelessWidget {
  const _SearchIndexStatusBanner({required this.state, this.onRetry});

  final SearchIndexBuildState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final children = <Widget>[];
    if (state.isBuilding) {
      children.addAll([
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.globalSearchIndexProgressSemantics(
              state.readyCount,
              state.total,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]);
    }
    if (state.failedCount > 0) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 12));
      children.add(
        Icon(Icons.warning_amber_rounded, size: 16, color: colors.error),
      );
      children.add(const SizedBox(width: 6));
      children.add(
        Expanded(
          child: Text(
            context.l10n.globalSearchIndexIncompletePlaylists(
              state.failedCount,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.error),
          ),
        ),
      );
      if (onRetry != null) {
        children.add(
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.globalSearchRetry),
          ),
        );
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: state.failedCount > 0
            ? colors.errorContainer.withValues(alpha: 0.5)
            : colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: children),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.item,
    required this.highlighted,
    required this.epgAsync,
  });

  final GlobalSearchResultItem item;
  final bool highlighted;
  final AsyncValue<Map<int, SearchEpgLine>> epgAsync;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = highlighted
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final iconForeground = highlighted
        ? colors.onSecondaryContainer
        : colors.secondary;

    final channel = item.channel;
    if (channel != null) {
      final epgLine = epgAsync.when(
        loading: () => context.l10n.globalSearchEpgLoading,
        error: (_, _) => context.l10n.globalSearchEpgUnavailable,
        data: (lines) => switch (lines[channel.channelId]?.state) {
          SearchEpgLineState.current => context.l10n.globalSearchEpgNow(
            lines[channel.channelId]?.title ?? '',
          ),
          _ => context.l10n.globalSearchEpgNone,
        },
      );
      return _rowLayout(
        context,
        icon: Icons.live_tv_rounded,
        iconForeground: iconForeground,
        title: channel.visibleLabel,
        subtitles: [channel.metadataLabel, epgLine],
        foreground: foreground,
      );
    }

    final category = item.category!;
    return _rowLayout(
      context,
      icon: _categorySearchIcon(category.target),
      iconForeground: iconForeground,
      title: category.categoryName,
      subtitles: [_categoryMetadataLabel(context, category)],
      foreground: foreground,
      trailing: category.isPinned
          ? Icon(Icons.push_pin_rounded, size: 16, color: iconForeground)
          : null,
    );
  }

  Widget _rowLayout(
    BuildContext context, {
    required IconData icon,
    required Color iconForeground,
    required String title,
    required List<String> subtitles,
    required Color foreground,
    Widget? trailing,
  }) {
    return SizedBox(
      height: subtitles.length > 1 ? 76 : 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconForeground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final subtitle in subtitles)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.78),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

String _itemLabel(BuildContext context, GlobalSearchResultItem item) {
  final channel = item.channel;
  if (channel != null) {
    return context.l10n.globalSearchResultSemantics(
      channel.visibleLabel,
      channel.metadataLabel,
    );
  }
  return _categoryVisibleLabel(context, item.category!);
}

String _categoryTargetLabel(
  BuildContext context,
  CategorySearchTarget target,
) => switch (target) {
  CategorySearchTarget.live => context.l10n.globalSearchTargetLive,
  CategorySearchTarget.movies => context.l10n.globalSearchTargetMovies,
  CategorySearchTarget.series => context.l10n.globalSearchTargetSeries,
};

String _categoryVisibleLabel(
  BuildContext context,
  CategorySearchResult category,
) => context.l10n.globalSearchCategoryVisibleLabel(
  category.categoryName,
  _categoryTargetLabel(context, category.target),
  category.playlistName,
);

String _categoryMetadataLabel(
  BuildContext context,
  CategorySearchResult category,
) => context.l10n.globalSearchCategoryMetadata(
  _categoryTargetLabel(context, category.target),
  category.playlistName,
);

String _searchOverlayFilterLabel(
  BuildContext context,
  SearchOverlayFilter filter,
) => switch (filter) {
  SearchOverlayFilter.all => context.l10n.globalSearchFilterAll,
  SearchOverlayFilter.channels => context.l10n.globalSearchFilterChannels,
  SearchOverlayFilter.categories => context.l10n.globalSearchFilterCategories,
};

String _itemKey(GlobalSearchResultItem item) {
  final channel = item.channel;
  if (channel != null) return 'global-search-channel-${channel.channelId}';
  final category = item.category!;
  return 'global-search-category-${category.playlistId}-${category.target.name}-${category.categoryName}';
}

SearchOverlayFilter _nextFilter(SearchOverlayFilter filter) {
  final values = SearchOverlayFilter.values;
  return values[(filter.index + 1) % values.length];
}

SearchOverlayFilter _previousFilter(SearchOverlayFilter filter) {
  final values = SearchOverlayFilter.values;
  return values[(filter.index - 1 + values.length) % values.length];
}

IconData _categorySearchIcon(CategorySearchTarget target) => switch (target) {
  CategorySearchTarget.live => Icons.live_tv_rounded,
  CategorySearchTarget.movies => Icons.movie_rounded,
  CategorySearchTarget.series => Icons.tv_rounded,
};

/// SearchBar's framework InkWell is focusable in addition to its TextField.
/// Keep the pointer surface in the tree, but omit that decorative focus stop
/// from keyboard traversal so Tab lands directly in the editable field.
class _SearchBarTraversalPolicy extends WidgetOrderTraversalPolicy {
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    return super
        .sortDescendants(descendants, currentNode)
        .where(_isKeyboardControl);
  }

  bool _isKeyboardControl(FocusNode node) {
    final context = node.context;
    if (context == null) return true;
    if (context.findAncestorWidgetOfExactType<EditableText>() != null) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<InkWell>() == null;
  }
}
