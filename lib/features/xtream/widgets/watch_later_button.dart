import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';

/// Tonal bookmark action shared by the VOD, series, and Watch Later surfaces.
class WatchLaterButton extends ConsumerWidget {
  const WatchLaterButton({super.key, required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(channelWatchLaterControllerProvider);
    final saved = channel.isWatchLater;
    final label = saved
        ? 'Aus Später ansehen entfernen'
        : 'Für später speichern';

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
