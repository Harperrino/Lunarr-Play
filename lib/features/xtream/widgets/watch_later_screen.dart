import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/movie_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/watch_later_button.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Manual, playlist-scoped Watch Later catalogue for VOD and series titles.
class WatchLaterScreen extends ConsumerWidget {
  const WatchLaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(watchLaterChannelsStreamProvider);
    final items = ref.watch(watchLaterChannelsProvider);
    final selectedPlaylist = ref.watch(selectedPlaylistIdProvider);

    return AppSurface(
      key: const ValueKey('watch-later-screen-surface'),
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.all(20),
      child: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _WatchLaterMessage(
          icon: Icons.error_outline_rounded,
          title: 'Später ansehen konnte nicht geladen werden',
          subtitle: '$error',
        ),
        data: (_) {
          if (selectedPlaylist == null) {
            return const _WatchLaterMessage(
              icon: Icons.playlist_play_rounded,
              title: 'Keine Playlist ausgewählt',
              subtitle: 'Wähle zuerst eine aktive Playlist aus.',
            );
          }
          if (items.isEmpty) {
            return const _WatchLaterMessage(
              icon: Icons.bookmark_border_rounded,
              title: 'Noch nichts für später gespeichert',
              subtitle:
                  'Markiere Filme oder Serientitel mit dem Lesezeichen, um sie hier zu behalten.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columnCount(constraints.maxWidth);
              final spacing = 14.0;
              final cellWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              final textScale = MediaQuery.textScalerOf(
                context,
              ).scale(1).clamp(1, 2);
              final cellHeight = cellWidth / (2 / 3) + 70 * textScale;
              return GridView.builder(
                key: const PageStorageKey<String>('watch-later-grid'),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  mainAxisExtent: cellHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final channel = items[index];
                  final isSeries = channel.channelType == 'series';
                  return isSeries
                      ? SeriesCard(
                          channel: channel,
                          posterAction: WatchLaterButton(channel: channel),
                          onTap: () =>
                              ref
                                      .read(
                                        selectedSeriesChannelProvider.notifier,
                                      )
                                      .state =
                                  channel,
                        )
                      : MovieCard(
                          channel: channel,
                          posterAction: WatchLaterButton(channel: channel),
                          onTap: () => ref
                              .read(playbackPrepControllerProvider.notifier)
                              .selectTarget(
                                PlaybackPrepTarget(
                                  playbackChannel: channel,
                                  streamUrl: channel.streamUrl,
                                  posterUrl: channel.logo,
                                  subtitle: channel.groupName,
                                ),
                              ),
                        );
                },
              );
            },
          );
        },
      ),
    );
  }

  static int _columnCount(double width) {
    if (width >= 1500) return 7;
    if (width >= 1280) return 6;
    if (width >= 1040) return 5;
    if (width >= 820) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}

class _WatchLaterMessage extends StatelessWidget {
  const _WatchLaterMessage({
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
