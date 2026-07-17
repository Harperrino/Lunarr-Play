import 'package:flutter/material.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';

/// Vertical grid lines aligned with 30-minute timeline slots.
class EpgTimelineSlotLines extends StatelessWidget {
  const EpgTimelineSlotLines({
    super.key,
    required this.windowStart,
    required this.windowEnd,
    required this.pixelsPerMinute,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final double pixelsPerMinute;

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];
    var slotStart = _floorToSlot(windowStart);
    while (slotStart.isBefore(windowEnd)) {
      final left = epgGridTimeToOffset(
        windowStart,
        slotStart,
        pixelsPerMinute: pixelsPerMinute,
      );
      lines.add(
        Positioned(
          left: left,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      );
      slotStart = slotStart.add(const Duration(minutes: epgGridSlotMinutes));
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: lines,
    );
  }

  DateTime _floorToSlot(DateTime time) {
    final minute = (time.minute ~/ epgGridSlotMinutes) * epgGridSlotMinutes;
    return DateTime(time.year, time.month, time.day, time.hour, minute);
  }
}
