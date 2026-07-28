import 'package:flutter/material.dart';

import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Provider-free favorite action shared by Live and Favorites lists.
class ChannelFavoriteButton extends StatelessWidget {
  const ChannelFavoriteButton({
    super.key,
    required this.channelId,
    required this.isFavorite,
    required this.isBusy,
    required this.onToggle,
  });

  final int channelId;
  final bool isFavorite;
  final bool isBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final label = isFavorite
        ? context.l10n.channelFavoriteRemove
        : context.l10n.channelFavoriteAdd;
    final colorScheme = Theme.of(context).colorScheme;

    return M3ActionSlot(
      key: ValueKey('channel-favorite-toggle-$channelId'),
      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      foregroundColor: isFavorite
          ? colorScheme.onTertiaryContainer
          : colorScheme.onSurfaceVariant,
      backgroundColor: isFavorite
          ? colorScheme.tertiaryContainer
          : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isFavorite
            ? BorderSide.none
            : BorderSide(color: colorScheme.outlineVariant),
      ),
      tooltip: label,
      semanticLabel: label,
      toggled: isFavorite,
      onPressed: isBusy ? null : onToggle,
    );
  }
}
