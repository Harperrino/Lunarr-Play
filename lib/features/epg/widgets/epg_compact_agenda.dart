import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_interactive_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// The EPG switches to its agenda at the shared Compact content breakpoint.
const double epgCompactAgendaBreakpoint = 720;

/// Keeps the responsive decision independently testable from the screen.
bool usesEpgCompactAgenda(double availableWidth) =>
    availableWidth < epgCompactAgendaBreakpoint;

/// Preserves the established EPG activation order while keeping it testable.
void activateEpgChannel({
  required Channel channel,
  required ValueChanged<Channel> onSelectChannel,
  required ValueChanged<String> onOpenStream,
  required VoidCallback onShowLiveTab,
}) {
  onSelectChannel(channel);
  onOpenStream(channel.streamUrl);
  onShowLiveTab();
}

/// Leaves the desktop grid mounted at and above the Compact breakpoint.
class EpgAgendaResponsiveBody extends StatelessWidget {
  const EpgAgendaResponsiveBody({
    super.key,
    required this.compactChild,
    required this.desktopChild,
  });

  final Widget compactChild;
  final Widget desktopChild;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          usesEpgCompactAgenda(constraints.maxWidth)
          ? compactChild
          : desktopChild,
    );
  }
}

/// Provider-free, vertically scrollable programme agenda for compact widths.
class EpgCompactAgenda extends StatelessWidget {
  const EpgCompactAgenda({
    super.key,
    required this.rows,
    required this.now,
    required this.onChannelTap,
  });

  final List<EpgGridRowData> rows;
  final DateTime now;
  final ValueChanged<Channel> onChannelTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('epg-compact-agenda'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => EpgAgendaRow(
        key: ValueKey('epg-compact-agenda-row-${rows[index].channel.id}'),
        row: rows[index],
        now: now,
        onTap: () => onChannelTap(rows[index].channel),
      ),
    );
  }
}

/// Presentation-only compact programme row with an explicit current-show state.
class EpgAgendaRow extends StatelessWidget {
  const EpgAgendaRow({
    super.key,
    required this.row,
    required this.now,
    required this.onTap,
  });

  final EpgGridRowData row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final programmes = epgEntriesForGridDisplay(row.programs);
    final current = currentProgramAt(programmes, now);
    final next = epgAgendaNextProgramme(programmes, now);
    final isLive = current != null;
    final hasEpg = row.matchStatus == EpgMatchStatus.matched;
    final semanticLabel = epgAgendaSemanticLabel(
      channelName: row.channel.name,
      current: current,
      next: next,
      hasEpg: hasEpg,
    );

    return EpgInteractiveSurface(
      onTap: onTap,
      semanticLabel: semanticLabel,
      level: isLive ? AppSurfaceLevel.high : AppSurfaceLevel.standard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  row.channel.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (isLive) const _EpgLiveBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currentLine(current, hasEpg),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLive
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isLive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: 4),
              Text(
                'Danach: ${next.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _currentLine(EpgEntry? current, bool hasEpg) {
    if (current != null) return 'JETZT: ${current.title}';
    if (!hasEpg) return 'Kein EPG verfügbar';
    return 'Derzeit kein Programm';
  }
}

/// Finds the next programme without changing the established EPG time model.
///
/// Programme intervals are half-open (`[startTime, endTime)`) in the EPG
/// helpers. A programme that starts exactly at [now] is therefore the current
/// programme, not a second "Danach" item.
EpgEntry? epgAgendaNextProgramme(List<EpgEntry> programmes, DateTime now) {
  for (final programme in programmes) {
    if (programme.startTime.isAfter(now)) return programme;
  }
  return null;
}

/// Human-readable status for assistive technologies, independent of colour.
String epgAgendaSemanticLabel({
  required String channelName,
  required EpgEntry? current,
  required EpgEntry? next,
  required bool hasEpg,
}) {
  final parts = <String>['Sender: $channelName'];
  if (current != null) {
    parts.add('LIVE, läuft jetzt: ${current.title}');
  } else if (!hasEpg) {
    parts.add('Kein EPG verfügbar');
  } else {
    parts.add('Derzeit kein Programm');
  }
  if (next != null) parts.add('Danach: ${next.title}');
  parts.add('Sender starten');
  return parts.join('. ');
}

class _EpgLiveBadge extends StatelessWidget {
  const _EpgLiveBadge();

  @override
  Widget build(BuildContext context) {
    final liveContainer = Theme.of(
      context,
    ).extension<AppStatusColors>()!.liveContainer;
    final onLiveContainer = Theme.of(
      context,
    ).extension<AppStatusColors>()!.onLiveContainer;
    return Semantics(
      label: 'LIVE, läuft jetzt',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: liveContainer,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radio_rounded, size: 14, color: onLiveContainer),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: onLiveContainer,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
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
