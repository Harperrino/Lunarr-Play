import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';

/// Horizontal time axis with 30-minute slots and draggable column resize handles.
class EpgTimelineHeader extends ConsumerWidget {
  const EpgTimelineHeader({
    super.key,
    required this.windowStart,
    required this.windowEnd,
    required this.timelineWidth,
    required this.pixelsPerMinute,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final double timelineWidth;
  final double pixelsPerMinute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = <Widget>[];
    final slotWidth = epgGridSlotWidth(pixelsPerMinute);
    var slotStart = _floorToSlot(windowStart);
    while (slotStart.isBefore(windowEnd)) {
      final left = epgGridTimeToOffset(
        windowStart,
        slotStart,
        pixelsPerMinute: pixelsPerMinute,
      );
      slots.add(
        Positioned(
          left: left,
          width: slotWidth,
          top: 0,
          bottom: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: 6, top: 8, right: 6),
                child: Text(
                  _formatSlotLabel(slotStart),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: epgGridSlotResizeHandleWidth,
                child: _EpgSlotResizeHandle(
                  onDrag: (deltaDx) {
                    adjustEpgGridPixelsPerMinute(
                      ref,
                      deltaDx / epgGridSlotMinutes,
                    );
                  },
                  onKeyboardAdjust: (deltaPixelsPerMinute) {
                    adjustEpgGridPixelsPerMinute(ref, deltaPixelsPerMinute);
                  },
                ),
              ),
            ],
          ),
        ),
      );
      slotStart = slotStart.add(const Duration(minutes: epgGridSlotMinutes));
    }

    return SizedBox(
      width: timelineWidth,
      height: 36,
      child: Stack(clipBehavior: Clip.none, children: slots),
    );
  }

  DateTime _floorToSlot(DateTime time) {
    final minute = (time.minute ~/ epgGridSlotMinutes) * epgGridSlotMinutes;
    return DateTime(time.year, time.month, time.day, time.hour, minute);
  }

  String _formatSlotLabel(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EpgSlotResizeHandle extends StatefulWidget {
  const _EpgSlotResizeHandle({
    required this.onDrag,
    required this.onKeyboardAdjust,
  });

  final ValueChanged<double> onDrag;
  final ValueChanged<double> onKeyboardAdjust;

  @override
  State<_EpgSlotResizeHandle> createState() => _EpgSlotResizeHandleState();
}

class _EpgSlotResizeHandleState extends State<_EpgSlotResizeHandle> {
  static const _keyboardResizeStep = 0.25;

  final FocusNode _focusNode = FocusNode(
    debugLabel: 'EPG column resize handle',
  );
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final double? delta;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      delta = _keyboardResizeStep;
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      delta = -_keyboardResizeStep;
    } else {
      delta = null;
    }
    if (delta == null) return KeyEventResult.ignored;

    widget.onKeyboardAdjust(delta);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging || _focused;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _focusNode.requestFocus(),
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: Focus(
          focusNode: _focusNode,
          onFocusChange: (focused) {
            if (_focused != focused) setState(() => _focused = focused);
          },
          onKeyEvent: _handleKeyEvent,
          child: Semantics(
            container: true,
            focusable: true,
            label: 'Zeitspaltenbreite anpassen',
            hint: 'Mit Pfeiltasten schrittweise ändern',
            onIncrease: () => widget.onKeyboardAdjust(_keyboardResizeStep),
            onDecrease: () => widget.onKeyboardAdjust(-_keyboardResizeStep),
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: active ? 3 : 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
