import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_media_card.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

class DiscoveryShelfView extends StatefulWidget {
  const DiscoveryShelfView({
    super.key,
    required this.shelf,
    required this.onSelect,
    required this.onShowAll,
    this.selected,
  });

  final DiscoveryShelf shelf;
  final DiscoveryMediaItem? selected;
  final ValueChanged<DiscoveryMediaItem> onSelect;
  final VoidCallback onShowAll;

  @override
  State<DiscoveryShelfView> createState() => _DiscoveryShelfViewState();
}

class _DiscoveryShelfViewState extends State<DiscoveryShelfView> {
  final ScrollController _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateExtent());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateExtent)
      ..dispose();
    super.dispose();
  }

  void _updateExtent() {
    if (!mounted || !_controller.hasClients) return;
    final nextBack = _controller.offset > 0.5;
    final nextForward =
        _controller.offset < _controller.position.maxScrollExtent - 0.5;
    if (_canBack != nextBack || _canForward != nextForward) {
      setState(() {
        _canBack = nextBack;
        _canForward = nextForward;
      });
    }
  }

  void _move(double direction) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + direction * 460).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    unawaited(
      _controller.animateTo(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highTextScale = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  discoveryShelfTitle(context.l10n, widget.shelf.kind),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: widget.onShowAll,
                child: Text(context.l10n.discoveryShowAll),
              ),
              IconButton(
                tooltip: context.l10n.discoveryShelfPrevious,
                onPressed: _canBack ? () => _move(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: context.l10n.discoveryShelfNext,
                onPressed: _canForward ? () => _move(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: context.l10n.discoveryShelfSemantics(
              discoveryShelfTitle(context.l10n, widget.shelf.kind),
            ),
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _move(-1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _move(1);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                height: highTextScale ? 390 : 320,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const <PointerDeviceKind>{
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: Scrollbar(
                    controller: _controller,
                    thumbVisibility: true,
                    interactive: true,
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 10),
                      itemCount: widget.shelf.items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = widget.shelf.items[index];
                        return DiscoveryMediaCard(
                          item: item,
                          selected:
                              widget.selected?.id == item.id &&
                              widget.selected?.mediaType == item.mediaType,
                          onActivate: () => widget.onSelect(item),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
