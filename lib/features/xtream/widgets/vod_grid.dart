import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/movie_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_poster_image.dart'
    show vodPosterAspectRatio;
import 'package:m3uxtream_player/features/xtream/widgets/watch_later_button.dart';
import 'package:m3uxtream_player/shared/widgets/app_scrollbar.dart';

const double _vodGridSpacing = 14;
const PageStorageKey<String> _vodGridScrollKey = PageStorageKey<String>(
  'vod-grid-scroll',
);

/// Responsive poster grid for VOD movies.
class VodGrid extends ConsumerStatefulWidget {
  const VodGrid({super.key, required this.channels});

  final List<Channel> channels;

  @override
  ConsumerState<VodGrid> createState() => _VodGridState();
}

class _VodGridState extends ConsumerState<VodGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannelId = ref.watch(
      playbackPrepTargetProvider.select((target) => target?.playbackChannel.id),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final totalSpacing = _vodGridSpacing * (columns - 1);
        final availableWidth = constraints.maxWidth - totalSpacing;
        final cellWidth = availableWidth > 0 ? availableWidth / columns : 0.0;
        final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
        final cellHeight = cellWidth / vodPosterAspectRatio + 64 * textScale;

        return AppScrollbar(
          controller: _scrollController,
          axis: Axis.vertical,
          padding: const EdgeInsets.only(right: 6),
          child: GridView.builder(
            key: _vodGridScrollKey,
            controller: _scrollController,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _vodGridSpacing,
              crossAxisSpacing: _vodGridSpacing,
              mainAxisExtent: cellHeight,
            ),
            itemCount: widget.channels.length,
            itemBuilder: (context, index) {
              final channel = widget.channels[index];
              return MovieCard(
                channel: channel,
                isSelected: selectedChannelId == channel.id,
                onTap: () => _playMovie(channel),
                posterAction: WatchLaterButton(channel: channel),
              );
            },
          ),
        );
      },
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

  void _playMovie(Channel channel) {
    ref
        .read(playbackPrepControllerProvider.notifier)
        .selectTarget(
          PlaybackPrepTarget(
            playbackChannel: channel,
            streamUrl: channel.streamUrl,
            posterUrl: channel.logo,
            subtitle: channel.groupName,
          ),
        );
  }
}
