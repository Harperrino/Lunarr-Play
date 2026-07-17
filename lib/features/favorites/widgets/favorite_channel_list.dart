import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_favorite_button.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';

/// Presentation-only list of already-favourited live channels.
class FavoriteChannelList extends StatelessWidget {
  const FavoriteChannelList({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.onActivate,
    required this.onToggleFavorite,
    this.isFavoriteActionBusy = false,
  });

  final List<Channel> channels;
  final int? selectedChannelId;
  final ValueChanged<Channel> onActivate;
  final ValueChanged<Channel> onToggleFavorite;
  final bool isFavoriteActionBusy;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      // Keep the existing widget-test/automation anchor while the scrollable
      // gets its own PageStorage identity below.
      key: const ValueKey('favorite-channel-list'),
      child: ListView.separated(
        key: const PageStorageKey<String>('favorite-channel-list-scroll'),
        itemCount: channels.length,
        padding: const EdgeInsets.only(bottom: 4),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final channel = channels[index];
          return FavoriteChannelTile(
            channel: channel,
            isSelected: channel.id == selectedChannelId,
            onActivate: () => onActivate(channel),
            onToggleFavorite: () => onToggleFavorite(channel),
            isFavoriteActionBusy: isFavoriteActionBusy,
          );
        },
      ),
    );
  }
}

class FavoriteChannelTile extends StatelessWidget {
  const FavoriteChannelTile({
    super.key,
    required this.channel,
    required this.isSelected,
    required this.onActivate,
    required this.onToggleFavorite,
    required this.isFavoriteActionBusy,
  });

  final Channel channel;
  final bool isSelected;
  final VoidCallback onActivate;
  final VoidCallback onToggleFavorite;
  final bool isFavoriteActionBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final channel = this.channel;

    return M3MediaListItem(
      title: channel.name,
      surfaceKey: ValueKey('favorite-channel-tile-${channel.id}'),
      semanticLabel: 'Favorit: ${channel.name}',
      leading: Icon(
        Icons.favorite_rounded,
        color: colorScheme.tertiary,
        semanticLabel: 'Favorit',
      ),
      subtitle: (channel.groupName ?? '').trim().isEmpty
          ? null
          : Text(
              channel.groupName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
      selected: isSelected,
      onActivate: onActivate,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChannelFavoriteButton(
            channelId: channel.id,
            isFavorite: channel.isFavorite,
            isBusy: isFavoriteActionBusy,
            onToggle: onToggleFavorite,
          ),
          const SizedBox(width: 4),
          M3LeadingSlot(
            child: Icon(
              Icons.play_arrow_rounded,
              color: colorScheme.primary,
              semanticLabel: 'Live abspielen',
            ),
          ),
        ],
      ),
    );
  }
}
