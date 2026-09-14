import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Tonal bookmark action shared by the VOD, series, and Watch Later surfaces.
class WatchLaterButton extends ConsumerWidget {
  const WatchLaterButton({super.key, required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(channelWatchLaterControllerProvider);
    final saved = channel.isWatchLater;
    final label = saved
        ? context.l10n.watchLaterRemove
        : context.l10n.watchLaterSave;

    final colors = Theme.of(context).colorScheme;
    return M3ActionSlot(
      tooltip: label,
      semanticLabel: label,
      toggled: saved,
      foregroundColor: saved
          ? colors.onSecondaryContainer
          : colors.onSurfaceVariant,
      backgroundColor: saved
          ? colors.secondaryContainer
          : colors.surfaceContainerHighest,
      onPressed: action.isLoading
          ? null
          : () => ref
                .read(channelWatchLaterControllerProvider.notifier)
                .toggle(channel.id),
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
    );
  }
}
