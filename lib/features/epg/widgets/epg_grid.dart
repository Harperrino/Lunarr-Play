import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/controllers/epg_scroll_coordinator.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_program_cell.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_grid_frame.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_interactive_surface.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_now_marker.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_scroll_behavior.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_timeline_header.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_timeline_slot_lines.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/shared/widgets/app_scrollbar.dart';

const _horizontalScrollbarHeight = 14.0;
const _headerHeight = 36.0;

/// Scrollable EPG grid — fixed channel column + synced virtualized programme rows.
class EpgGrid extends ConsumerStatefulWidget {
  const EpgGrid({super.key});

  @override
  ConsumerState<EpgGrid> createState() => _EpgGridState();
}

class _EpgGridState extends ConsumerState<EpgGrid> {
  final EpgScrollCoordinator _scroll = EpgScrollCoordinator();
  bool _didInitialScrollToNow = false;

  ScrollController get _horizontalBodyScroll => _scroll.horizontalBody;
  ScrollController get _horizontalHeaderScroll => _scroll.horizontalHeader;
  ScrollController get _horizontalTrackScroll => _scroll.horizontalTrack;
  ScrollController get _verticalScroll => _scroll.verticalChannels;
  ScrollController get _verticalProgramScroll => _scroll.verticalPrograms;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToNow();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _syncHorizontalBodyFromHeader() {
    _scroll.syncHorizontalBodyFromHeader();
  }

  void _syncHorizontalBodyFromTrack() {
    _scroll.syncHorizontalBodyFromTrack();
  }

  void _scrollHorizontalBy(double delta) {
    _scroll.scrollHorizontalBy(delta);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    if (dx.abs() >= dy.abs() && dx != 0) {
      _scrollHorizontalBy(-dx);
      return;
    }
    if (_shiftPressed && dy != 0) {
      _scrollHorizontalBy(-dy);
    }
  }

  bool get _shiftPressed {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
        keyboard.isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);
  }

  void _preserveScrollTimeOnZoom(double oldPpm, double newPpm) {
    if (oldPpm == newPpm || !_horizontalBodyScroll.hasClients) return;
    final anchorOffset = _horizontalBodyScroll.offset;
    final scaledOffset = EpgScrollCoordinator.scaledOffsetForZoom(
      anchorOffset,
      oldPpm,
      newPpm,
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalBodyScroll.hasClients) return;
      final position = _horizontalBodyScroll.position;
      _horizontalBodyScroll.jumpTo(
        scaledOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  void _scheduleScrollToNow() {
    if (!mounted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(epgGridScrollToNowTickProvider, (previous, next) {
      if (previous != next) _scrollToNow();
    });

    ref.listen(epgGridEntriesStreamProvider, (previous, next) {
      if (next.hasValue && previous?.hasValue != true) {
        _scheduleScrollToNow();
      }
    });

    ref.listen(epgGridPixelsPerMinuteProvider, (previous, next) {
      if (previous != null) _preserveScrollTimeOnZoom(previous, next);
    });

    final windowStart = ref.watch(epgWindowStartProvider);
    final windowEnd = ref.watch(epgWindowEndProvider);
    final now = ref.watch(epgGridNowMarkerProvider);
    final rows = ref.watch(epgGridRowsProvider);
    final pixelsPerMinute = ref.watch(epgGridPixelsPerMinuteProvider);
    final timelineWidth = epgGridTimelineWidth(
      windowStart,
      windowEnd,
      pixelsPerMinute: pixelsPerMinute,
    );
    final nowOffset = epgGridTimeToOffset(
      windowStart,
      now,
      pixelsPerMinute: pixelsPerMinute,
    );
    final showNowLine = !now.isBefore(windowStart) && now.isBefore(windowEnd);

    return ScrollConfiguration(
      behavior: const EpgScrollBehavior(),
      child: EpgGridFrame(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: epgGridChannelColumnWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: _headerHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'CHANNEL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Expanded(
                          child: AppScrollbar(
                            controller: _verticalScroll,
                            axis: Axis.vertical,
                            padding: const EdgeInsets.only(right: 8),
                            child: ListView.builder(
                              controller: _verticalScroll,
                              primary: false,
                              padding: const EdgeInsets.only(right: 6),
                              itemCount: rows.length,
                              itemExtent: epgGridRowHeight,
                              itemBuilder: (context, index) => RepaintBoundary(
                                child: _EpgChannelCell(
                                  row: rows[index],
                                  now: now,
                                  onTap: _playChannel,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: _headerHeight,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.axis ==
                                      Axis.horizontal &&
                                  notification is ScrollUpdateNotification) {
                                _syncHorizontalBodyFromHeader();
                              }
                              return false;
                            },
                            child: AppScrollbar(
                              controller: _horizontalHeaderScroll,
                              axis: Axis.horizontal,
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _horizontalHeaderScroll,
                                primary: false,
                                child: SizedBox(
                                  width: timelineWidth,
                                  child: EpgTimelineHeader(
                                    windowStart: windowStart,
                                    windowEnd: windowEnd,
                                    timelineWidth: timelineWidth,
                                    pixelsPerMinute: pixelsPerMinute,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AppScrollbar(
                                controller: _horizontalBodyScroll,
                                axis: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Listener(
                                  onPointerSignal: _handlePointerSignal,
                                  child: RawGestureDetector(
                                    gestures: {
                                      HorizontalDragGestureRecognizer:
                                          GestureRecognizerFactoryWithHandlers<
                                            HorizontalDragGestureRecognizer
                                          >(
                                            () =>
                                                HorizontalDragGestureRecognizer(),
                                            (instance) {
                                              instance.onUpdate = (details) =>
                                                  _scrollHorizontalBy(
                                                    -details.delta.dx,
                                                  );
                                            },
                                          ),
                                    },
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      controller: _horizontalBodyScroll,
                                      primary: false,
                                      child: SizedBox(
                                        width: timelineWidth,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            ListView.builder(
                                              controller:
                                                  _verticalProgramScroll,
                                              primary: false,
                                              padding: const EdgeInsets.only(
                                                right: 6,
                                              ),
                                              itemCount: rows.length,
                                              itemExtent: epgGridRowHeight,
                                              itemBuilder: (context, index) =>
                                                  ClipRect(
                                                    child: SizedBox(
                                                      width: timelineWidth,
                                                      child: RepaintBoundary(
                                                        child: _EpgProgramRow(
                                                          row: rows[index],
                                                          windowStart:
                                                              windowStart,
                                                          windowEnd: windowEnd,
                                                          now: now,
                                                          pixelsPerMinute:
                                                              pixelsPerMinute,
                                                          onProgramTap:
                                                              _playChannel,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                            if (showNowLine)
                                              Positioned(
                                                left: nowOffset,
                                                top: 0,
                                                bottom: 0,
                                                child: IgnorePointer(
                                                  child: const EpgNowMarker(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _horizontalScrollbarHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: epgGridChannelColumnWidth),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.horizontal &&
                        notification is ScrollUpdateNotification) {
                      _syncHorizontalBodyFromTrack();
                    }
                    return false;
                  },
                  child: AppScrollbar(
                    controller: _horizontalTrackScroll,
                    axis: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalTrackScroll,
                      primary: false,
                      child: SizedBox(
                        width: timelineWidth,
                        height: _horizontalScrollbarHeight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToNow() {
    if (!mounted) return;
    if (!_horizontalBodyScroll.hasClients) {
      if (!_didInitialScrollToNow) {
        _scheduleScrollToNow();
      }
      return;
    }

    _didInitialScrollToNow = true;
    final windowStart = ref.read(epgWindowStartProvider);
    final now = ref.read(epgGridNowMarkerProvider);
    final pixelsPerMinute = ref.read(epgGridPixelsPerMinuteProvider);
    final target =
        epgGridTimeToOffset(
          windowStart,
          now,
          pixelsPerMinute: pixelsPerMinute,
        ) -
        120;
    _horizontalBodyScroll.jumpTo(
      target.clamp(
        _horizontalBodyScroll.position.minScrollExtent,
        _horizontalBodyScroll.position.maxScrollExtent,
      ),
    );
  }

  void _playChannel(Channel channel) {
    ref.read(selectedChannelProvider.notifier).state = channel;
    ref.read(playerNotifierProvider.notifier).openStream(channel.streamUrl);
    ref.read(activeSidebarIndexProvider.notifier).state = 0;
  }
}

class _EpgChannelCell extends StatelessWidget {
  const _EpgChannelCell({
    required this.row,
    required this.now,
    required this.onTap,
  });

  final EpgGridRowData row;
  final DateTime now;
  final ValueChanged<Channel> onTap;

  @override
  Widget build(BuildContext context) {
    final hasMatch = row.matchStatus == EpgMatchStatus.matched;

    return EpgInteractiveSurface(
      onTap: () => onTap(row.channel),
      semanticLabel:
          'Sender: ${row.channel.name}. ${epgGridRowSubtitle(row, now)}',
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  row.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  epgGridRowSubtitle(row, now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                        .withValues(alpha: hasMatch ? 1 : 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpgProgramRow extends StatelessWidget {
  const _EpgProgramRow({
    required this.row,
    required this.windowStart,
    required this.windowEnd,
    required this.now,
    required this.pixelsPerMinute,
    required this.onProgramTap,
  });

  final EpgGridRowData row;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime now;
  final double pixelsPerMinute;
  final ValueChanged<Channel> onProgramTap;

  @override
  Widget build(BuildContext context) {
    final hasMatch = row.matchStatus == EpgMatchStatus.matched;
    final visiblePrograms = hasMatch
        ? epgEntriesVisibleForGrid(row.programs, windowStart, windowEnd)
        : const <EpgEntry>[];

    return SizedBox(
      height: epgGridRowHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          EpgTimelineSlotLines(
            windowStart: windowStart,
            windowEnd: windowEnd,
            pixelsPerMinute: pixelsPerMinute,
          ),
          if (hasMatch && visiblePrograms.isNotEmpty)
            ...visiblePrograms.map((entry) {
              final isLive =
                  !entry.startTime.isAfter(now) && entry.endTime.isAfter(now);
              return EpgProgramCell(
                key: ValueKey(
                  '${entry.id}-${entry.startTime.millisecondsSinceEpoch}',
                ),
                entry: entry,
                windowStart: windowStart,
                windowEnd: windowEnd,
                pixelsPerMinute: pixelsPerMinute,
                isLive: isLive,
                onTap: () => onProgramTap(row.channel),
              );
            })
          else if (hasMatch && row.programs.isEmpty)
            Center(
              child: Text(
                'Kein Programm',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (!hasMatch)
            Center(
              child: Text(
                'Kein EPG',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
