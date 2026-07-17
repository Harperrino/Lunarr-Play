import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';

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
  bool _syncingFromProvider = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onLocalTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onLocalTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(globalSearchQueryProvider);

    if (!_syncingFromProvider && _controller.text != query) {
      _applyProviderQuery(query);
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
          hintText: 'Search channels, movies, series...',
          onChanged: _onTextChanged,
          onSubmitted: _onTextChanged,
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

        return Semantics(
          textField: true,
          label: 'Global search',
          child: FocusTraversalGroup(
            policy: _SearchBarTraversalPolicy(),
            child: SizedBox(
              width: effectiveWidth,
              height: GlobalSearchField.fieldHeight,
              child: searchBar,
            ),
          ),
        );
      },
    );
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
