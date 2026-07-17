import 'package:flutter/material.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_poster_image.dart'
    show vodPosterAspectRatio;
import 'package:m3uxtream_player/features/xtream/widgets/watch_later_button.dart';
import 'package:m3uxtream_player/shared/widgets/app_scrollbar.dart';

const double _seriesGridSpacing = 14;
const PageStorageKey<String> _seriesGridScrollKey = PageStorageKey<String>(
  'series-grid-scroll',
);

/// Responsive poster grid for series catalogue.
class SeriesGrid extends StatefulWidget {
  const SeriesGrid({
    super.key,
    required this.channels,
    required this.onSeriesTap,
  });

  final List<Channel> channels;
  final ValueChanged<Channel> onSeriesTap;

  @override
  State<SeriesGrid> createState() => _SeriesGridState();
}

class _SeriesGridState extends State<SeriesGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final totalSpacing = _seriesGridSpacing * (columns - 1);
        final availableWidth = constraints.maxWidth - totalSpacing;
        final cellWidth = availableWidth > 0 ? availableWidth / columns : 0.0;
        final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
        final cellHeight = cellWidth / vodPosterAspectRatio + 64 * textScale;

        return AppScrollbar(
          controller: _scrollController,
          axis: Axis.vertical,
          padding: const EdgeInsets.only(right: 6),
          child: GridView.builder(
            key: _seriesGridScrollKey,
            controller: _scrollController,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _seriesGridSpacing,
              crossAxisSpacing: _seriesGridSpacing,
              mainAxisExtent: cellHeight,
            ),
            itemCount: widget.channels.length,
            itemBuilder: (context, index) {
              final channel = widget.channels[index];
              return SeriesCard(
                channel: channel,
                onTap: () => widget.onSeriesTap(channel),
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
}
