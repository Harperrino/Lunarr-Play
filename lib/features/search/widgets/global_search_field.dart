import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/search/models/category_search_result.dart';
import 'package:m3uxtream_player/features/search/models/global_search_results.dart';
import 'package:m3uxtream_player/features/search/models/search_overlay_filter.dart';
import 'package:m3uxtream_player/features/search/providers/category_search_providers.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/search/services/category_search_navigation.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_overlay_surface.dart';

Color globalSearchHintColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// Central search field for the app header - visible on every tab.
class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key, this.width = 720});

  static const fieldHeight = 56.0;

  final double width;

  @override
  ConsumerState<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final OverlayPortalController _overlayController;
  final GlobalKey _searchTargetKey = GlobalKey();
  int _highlightedIndex = 0;
  double? _overlayTop;
  SearchOverlayFilter _filter = SearchOverlayFilter.all;
  bool _syncingFromProvider = false;

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
    final results = ref.watch(globalSearchResultsProvider);
    final items = results.itemsFor(_filter);

    if (!_syncingFromProvider && _controller.text != query) {
      _applyProviderQuery(query);
    }
    if (_focusNode.hasFocus && query.trim().isNotEmpty && items.isNotEmpty) {
      _scheduleOverlayMeasurement();
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
          hintText: 'Search channels, movies, series...',
          onChanged: _onTextChanged,
          onSubmitted: _onSubmitted,
          textInputAction: TextInputAction.search,
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
          padding: const WidgetStatePropertyAll(
            EdgeInsets.only(left: 12, right: 4),
          ),
          textStyle: WidgetStatePropertyAll(TextStyle(color: colors.onSurface)),
          hintStyle: WidgetStatePropertyAll(
            TextStyle(color: globalSearchHintColor(context)),
          ),
          leading: SizedBox(
            width: 40,
            height: 48,
            child: Icon(Icons.search_rounded, size: 24, color: colors.primary),
          ),
          trailing: [
            if (query.isNotEmpty)
              IconButton(
                onPressed: _clear,
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                padding: EdgeInsets.zero,
                color: colors.onSurfaceVariant,
              ),
          ],
        );

        return OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (overlayContext) {
            if (!_focusNode.hasFocus || query.trim().isEmpty || items.isEmpty) {
              return const SizedBox.shrink();
            }

            final viewport = MediaQuery.sizeOf(overlayContext);
            final overlayWidth = math
                .min(
                  math.min(effectiveWidth, 480),
                  math.max(0, viewport.width - 24),
                )
                .toDouble();
            final top = (_overlayTop ?? GlobalSearchField.fieldHeight + 20)
                .clamp(12.0, math.max(12.0, viewport.height - 12.0))
                .toDouble();
            final maxHeight = math
                .max(64.0, viewport.height - top - 12.0)
                .toDouble();
            final highlightedIndex = _highlightedIndex
                .clamp(0, items.length - 1)
                .toInt();

            return Positioned(
              left: (viewport.width - overlayWidth) / 2,
              top: top,
              width: overlayWidth,
              child: _GlobalSearchOverlay(
                maxHeight: maxHeight,
                filter: _filter,
                items: items,
                highlightedIndex: highlightedIndex,
                onFilterChanged: _setFilter,
                onHighlighted: (index) {
                  if (_highlightedIndex == index) return;
                  setState(() => _highlightedIndex = index);
                },
                onSelected: _selectItem,
              ),
            );
          },
          child: Semantics(
            textField: true,
            label: 'Global search',
            child: FocusTraversalGroup(
              policy: _SearchBarTraversalPolicy(),
              child: SizedBox(
                key: _searchTargetKey,
                width: effectiveWidth,
                height: GlobalSearchField.fieldHeight,
                child: searchBar,
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleOverlayMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      final renderObject = _searchTargetKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final top =
          renderObject.localToGlobal(Offset.zero).dy +
          renderObject.size.height +
          8;
      if (_overlayTop == null || (_overlayTop! - top).abs() > 0.5) {
        setState(() => _overlayTop = top);
      }
    });
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) _scheduleOverlayMeasurement();
    setState(() => _highlightedIndex = 0);
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }

    final results = ref.read(globalSearchResultsProvider);
    final items = results.itemsFor(_filter);
    if (!_focusNode.hasFocus || items.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setFilter(_previousFilter(_filter));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setFilter(_nextFilter(_filter));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(
        () => _highlightedIndex = (_highlightedIndex + 1) % items.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlightedIndex =
            (_highlightedIndex - 1 + items.length) % items.length,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _selectItem(items[_highlightedIndex.clamp(0, items.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setFilter(SearchOverlayFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _highlightedIndex = 0;
    });
    ref.read(searchOverlayFilterProvider.notifier).state = filter;
  }

  void _onLocalTextChanged() {
    if (_syncingFromProvider) return;
    final next = _controller.text;
    if (ref.read(globalSearchQueryProvider) == next) return;
    ref.read(globalSearchQueryProvider.notifier).state = next;
  }

  void _onTextChanged(String value) {
    if (_syncingFromProvider) return;
    if (ref.read(globalSearchQueryProvider) == value) return;
    ref.read(globalSearchQueryProvider.notifier).state = value;
  }

  void _onSubmitted(String value) {
    _onTextChanged(value);
    final items = ref.read(globalSearchResultsProvider).itemsFor(_filter);
    if (items.isEmpty) return;
    _selectItem(items[_highlightedIndex.clamp(0, items.length - 1)]);
  }

  void _selectItem(GlobalSearchResultItem item) {
    final navigation = ref.read(categorySearchNavigationControllerProvider);
    if (item.channel case final channel?) {
      unawaited(navigation.openChannel(channel));
    } else if (item.category case final category?) {
      navigation.open(category);
    }
    _focusNode.unfocus();
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
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    ref.read(globalSearchQueryProvider.notifier).state = '';
  }
}

class _GlobalSearchOverlay extends ConsumerWidget {
  const _GlobalSearchOverlay({
    required this.maxHeight,
    required this.filter,
    required this.items,
    required this.highlightedIndex,
    required this.onFilterChanged,
    required this.onHighlighted,
    required this.onSelected,
  });

  final double maxHeight;
  final SearchOverlayFilter filter;
  final List<GlobalSearchResultItem> items;
  final int highlightedIndex;
  final ValueChanged<SearchOverlayFilter> onFilterChanged;
  final ValueChanged<int> onHighlighted;
  final ValueChanged<GlobalSearchResultItem> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final epgAsync = items.any((item) => item.isChannel)
        ? ref.watch(searchEpgLinesProvider)
        : const AsyncValue.data(<int, SearchEpgLine>{});

    return AppOverlaySurface(
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
                    label: Text(filter.label),
                  ),
              ],
              selected: {filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onFilterChanged(selection.first);
              },
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
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
                      label: _itemLabel(item),
                      hint: 'Öffnen',
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
              ),
            ),
          ],
        ),
      ),
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
        loading: () => 'EPG wird geladen…',
        error: (_, _) => 'EPG nicht verfügbar',
        data: (lines) => switch (lines[channel.channelId]?.state) {
          SearchEpgLineState.current =>
            'Jetzt: ${lines[channel.channelId]?.title ?? ''}',
          _ => 'Kein EPG',
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
      subtitles: [category.metadataLabel],
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

String _itemLabel(GlobalSearchResultItem item) {
  final channel = item.channel;
  if (channel != null) {
    return '${channel.visibleLabel} · ${channel.metadataLabel}';
  }
  return item.category!.visibleLabel;
}

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
