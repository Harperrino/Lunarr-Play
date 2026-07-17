import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/favorites/providers/favorite_channels_providers.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorite_channel_list.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/status_snack_bar.dart';

/// Dedicated M9a screen for the existing `Channel.isFavorite` live state.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(channelFavoriteControllerProvider, (previous, next) {
      if (!next.hasError || previous?.error == next.error) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appStatusSnackBar(
          context,
          message: 'Favorit konnte nicht gespeichert werden.',
          tone: AppStatusSnackBarTone.error,
        ),
      );
    });
    final channelsAsync = ref.watch(channelsStreamProvider);
    final favorites = ref.watch(favoriteLiveChannelsProvider);
    final selectedPlaylistId = ref.watch(selectedPlaylistIdProvider);
    final selectedChannel = ref.watch(selectedChannelProvider);
    final favoriteAction = ref.watch(channelFavoriteControllerProvider);

    return AppSurface(
      key: const ValueKey('favorites-screen-surface'),
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(20),
      child: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FavoritesMessage(
          icon: Icons.error_outline_rounded,
          title: 'Favoriten konnten nicht geladen werden',
          subtitle: error.toString(),
        ),
        data: (_) {
          if (selectedPlaylistId == null) {
            return const _FavoritesMessage(
              icon: Icons.playlist_play_rounded,
              title: 'Keine Playlist ausgewählt',
              subtitle:
                  'Wähle zuerst eine Playlist aus, um deine Favoriten zu sehen.',
            );
          }
          if (favorites.isEmpty) {
            return const _FavoritesMessage(
              icon: Icons.favorite_border_rounded,
              title: 'Noch keine Live-Favoriten',
              subtitle:
                  'Favoriten aus deiner aktiven Playlist erscheinen hier.',
            );
          }

          return FavoriteChannelList(
            channels: favorites,
            selectedChannelId: selectedChannel?.id,
            isFavoriteActionBusy: favoriteAction.isLoading,
            onToggleFavorite: (channel) => ref
                .read(channelFavoriteControllerProvider.notifier)
                .toggle(channel.id),
            onActivate: (channel) => activateFavoriteLiveChannel(
              channel: channel,
              onSelectChannel: (selected) =>
                  ref.read(selectedChannelProvider.notifier).state = selected,
              onOpenStream: (streamUrl) => ref
                  .read(playerNotifierProvider.notifier)
                  .openStream(streamUrl),
              onShowLiveTab: () =>
                  ref.read(activeSidebarIndexProvider.notifier).state =
                      shellLiveTabIndex,
            ),
          );
        },
      ),
    );
  }
}

/// Keeps the established Live activation order explicit and independently testable.
void activateFavoriteLiveChannel({
  required Channel channel,
  required ValueChanged<Channel> onSelectChannel,
  required ValueChanged<String> onOpenStream,
  required VoidCallback onShowLiveTab,
}) {
  onSelectChannel(channel);
  onOpenStream(channel.streamUrl);
  onShowLiveTab();
}

class _FavoritesMessage extends StatelessWidget {
  const _FavoritesMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
