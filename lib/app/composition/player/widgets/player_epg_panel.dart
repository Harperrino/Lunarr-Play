import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/selected_channel_epg_provider.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

class PlayerEpgPanel extends ConsumerWidget {
  const PlayerEpgPanel({super.key, required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channel = ref.watch(selectedChannelProvider);
    if (channel == null || channel.channelType != 'live') {
      return const SizedBox.shrink();
    }
    final programs = ref.watch(selectedChannelProgrammesProvider);
    final now = ref.watch(epgCurrentMinuteProvider);
    final selection = selectCurrentAndNextProgramme(
      programs.valueOrNull ?? const [],
      now,
    );
    final current = selection.current;
    final next = selection.next;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    String times(DateTime start, DateTime end) =>
        '${DateFormat.Hm().format(start.toLocal())} – ${DateFormat.Hm().format(end.toLocal())}';
    return Padding(
      key: const ValueKey('player-epg-panel'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current == null
                ? (programs.hasError
                      ? context.l10n.epgLoadError
                      : programs.isLoading
                      ? context.l10n.channelEpgLoading
                      : context.l10n.channelNoEpg)
                : context.l10n.channelEpgNow(current.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
          if (current != null) ...[
            Text(
              times(current.startTime, current.endTime),
              style: textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (!compact && current.description?.isNotEmpty == true)
              Text(
                current.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
          ],
          if (next != null)
            Text(
              context.l10n.epgPlayerNext(
                DateFormat.Hm().format(next.startTime.toLocal()),
                next.title,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
