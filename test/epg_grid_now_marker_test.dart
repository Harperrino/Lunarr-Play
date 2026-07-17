import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_grid.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_now_marker.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'now marker is omitted before the window and at its exclusive end',
    (tester) async {
      final windowStart = DateTime(2026, 7, 13, 10);
      final windowEnd = DateTime(2026, 7, 13, 22);

      for (final now in <DateTime>[
        windowStart.subtract(const Duration(minutes: 1)),
        windowEnd,
      ]) {
        final container = _container(
          windowStart: windowStart,
          windowEnd: windowEnd,
          now: now,
        );

        await _pumpGrid(tester, container);

        expect(find.byType(EpgNowMarker), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      }
    },
  );

  testWidgets(
    'now marker follows the timeline coordinate while the body scrolls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime(2026, 7, 13, 18);
      final windowStart = DateTime(2026, 7, 13, 6);
      final windowEnd = DateTime(2026, 7, 14, 6);
      final container = _container(
        windowStart: windowStart,
        windowEnd: windowEnd,
        now: now,
      );
      addTearDown(container.dispose);

      await _pumpGrid(tester, container);

      final marker = find.byType(EpgNowMarker);
      expect(marker, findsOneWidget);
      final before = tester.getTopLeft(marker).dx;
      final bodyScroll = find.ancestor(
        of: marker,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      expect(bodyScroll, findsOneWidget);
      final scrollable = find.ancestor(
        of: marker,
        matching: find.byType(Scrollable),
      );
      final scrollPosition = tester.state<ScrollableState>(scrollable).position;
      final beforeScrollOffset = scrollPosition.pixels;
      final pixelsPerMinute = container.read(epgGridPixelsPerMinuteProvider);
      final expectedInitialOffset =
          epgGridTimeToOffset(
            windowStart,
            now,
            pixelsPerMinute: pixelsPerMinute,
          ) -
          120;
      expect(
        beforeScrollOffset,
        closeTo(
          expectedInitialOffset.clamp(
            scrollPosition.minScrollExtent,
            scrollPosition.maxScrollExtent,
          ),
          1,
        ),
      );

      await tester.drag(bodyScroll, const Offset(-180, 0));
      await tester.pump();

      final after = tester.getTopLeft(marker).dx;
      final afterScrollOffset = scrollPosition.pixels;
      expect(after, lessThan(before - 20));
      expect(afterScrollOffset, greaterThan(beforeScrollOffset));
      expect(
        after - before,
        closeTo(-(afterScrollOffset - beforeScrollOffset), 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('queued EPG scroll callbacks are harmless after unmount', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 13, 18);
    final container = _container(
      windowStart: DateTime(2026, 7, 13, 6),
      windowEnd: DateTime(2026, 7, 14, 6),
      now: now,
    );
    addTearDown(container.dispose);

    await _pumpGrid(tester, container);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _container({
  required DateTime windowStart,
  required DateTime windowEnd,
  required DateTime now,
}) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWith(
        (ref) => throw StateError('EPG grid marker tests must not open DB'),
      ),
      epgGridRowsProvider.overrideWithValue([_row(windowStart, windowEnd)]),
      epgGridNowMarkerProvider.overrideWithValue(now),
      epgGridEntriesStreamProvider.overrideWith(
        (ref) => Stream.value(const <EpgEntry>[]),
      ),
    ],
  );
  container.read(epgWindowStartProvider.notifier).state = windowStart;
  container.read(epgWindowEndProvider.notifier).state = windowEnd;
  return container;
}

Future<void> _pumpGrid(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: SizedBox.expand(child: EpgGrid())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

EpgGridRowData _row(DateTime windowStart, DateTime windowEnd) {
  return EpgGridRowData(
    channel: const Channel(
      id: 1,
      playlistId: 1,
      streamId: null,
      name: 'Example channel',
      logo: null,
      groupName: 'Tests',
      tvgId: 'example.channel',
      streamUrl: 'https://example.invalid/live.m3u8',
      isFavorite: false,
      isWatchLater: false,
      channelType: 'live',
      lastWatchedPosition: null,
      duration: null,
      lastWatchedAt: null,
    ),
    matchStatus: EpgMatchStatus.matched,
    resolvedEpgChannelId: 'example.channel',
    programs: [
      EpgEntry(
        id: 1,
        channelId: 'example.channel',
        title: 'Example programme',
        description: null,
        startTime: windowStart,
        endTime: windowEnd,
      ),
    ],
  );
}
