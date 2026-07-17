import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_interactive_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// A single programme block on the EPG timeline.
class EpgProgramCell extends StatelessWidget {
  const EpgProgramCell({
    super.key,
    required this.entry,
    required this.windowStart,
    required this.windowEnd,
    required this.pixelsPerMinute,
    required this.onTap,
    this.isLive = false,
  });

  final EpgEntry entry;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double pixelsPerMinute;
  final VoidCallback onTap;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final layout = epgProgrammeLayout(
      windowStart: windowStart,
      windowEnd: windowEnd,
      entry: entry,
      pixelsPerMinute: pixelsPerMinute,
    );
    if (layout.width <= 0) return const SizedBox.shrink();

    final status = Theme.of(context).extension<AppStatusColors>()!;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return Positioned(
      left: layout.left,
      top: 6,
      width: layout.width,
      height: epgGridRowHeight - 12,
      child: EpgInteractiveSurface(
        onTap: onTap,
        semanticLabel: isLive
            ? 'Live jetzt: ${entry.title}'
            : 'Programm: ${entry.title}',
        level: isLive ? AppSurfaceLevel.high : AppSurfaceLevel.low,
        padding: EdgeInsets.zero,
        shape: shape,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isLive
                    ? status.live
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isLive ? 3 : 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      if (isLive && layout.width > 104) ...[
                        Icon(Icons.radio_rounded, size: 10, color: status.live),
                        const SizedBox(width: 3),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: status.live,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (layout.width > 70)
                  Text(
                    '${layout.durationMin} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
