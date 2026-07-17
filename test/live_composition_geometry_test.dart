import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/live_composition_geometry.dart';

void main() {
  group('LiveCompositionGeometry windowed layouts', () {
    test('uses the exact responsive breakpoints', () {
      expect(
        LiveCompositionGeometry.modeForWidth(719),
        LiveCompositionMode.compact,
      );
      expect(
        LiveCompositionGeometry.modeForWidth(720),
        LiveCompositionMode.medium,
      );
      expect(
        LiveCompositionGeometry.modeForWidth(1199),
        LiveCompositionMode.medium,
      );
      expect(
        LiveCompositionGeometry.modeForWidth(1200),
        LiveCompositionMode.expanded,
      );
      expect(
        LiveCompositionGeometry.modeForWidth(1600),
        LiveCompositionMode.wide,
      );
    });

    test(
      'compact keeps the stage full width for the bottom-sheet sender list',
      () {
        final layout = LiveCompositionGeometry.calculate(
          contentBounds: const Rect.fromLTWH(12, 24, 719, 600),
        );

        expect(layout.mode, LiveCompositionMode.compact);
        expect(layout.categoryRect, isNull);
        expect(layout.channelListRect, isNull);
        expect(layout.playerRect, const Rect.fromLTWH(12, 24, 719, 600));
        _expectBoundedAndSeparated(
          layout,
          const Rect.fromLTWH(12, 24, 719, 600),
        );
      },
    );

    test(
      'medium keeps channels left of a dominant player without categories',
      () {
        final layout = LiveCompositionGeometry.calculate(
          contentBounds: const Rect.fromLTWH(0, 0, 720, 500),
        );

        expect(layout.mode, LiveCompositionMode.medium);
        expect(layout.categoryRect, isNull);
        expect(layout.channelListRect!.width, inInclusiveRange(300, 340));
        expect(layout.channelListRect!.right, lessThan(layout.playerRect.left));
        _expectBoundedAndSeparated(layout, const Rect.fromLTWH(0, 0, 720, 500));
      },
    );

    test('medium collapses the sender list to the 64px rail token', () {
      final layout = LiveCompositionGeometry.calculate(
        contentBounds: const Rect.fromLTWH(0, 0, 720, 500),
        channelListExpanded: false,
      );

      expect(layout.mode, LiveCompositionMode.medium);
      expect(layout.channelListRect!.width, closeTo(64, 0.001));
      expect(layout.channelListRect!.right, lessThan(layout.playerRect.left));
      _expectBoundedAndSeparated(layout, const Rect.fromLTWH(0, 0, 720, 500));
    });

    test(
      'expanded orders category, channels, and player from left to right',
      () {
        final layout = LiveCompositionGeometry.calculate(
          contentBounds: const Rect.fromLTWH(10, 20, 1200, 720),
        );

        expect(layout.mode, LiveCompositionMode.expanded);
        expect(layout.categoryRect!.width, 232);
        expect(layout.channelListRect!.width, 376);
        expect(
          layout.categoryRect!.right,
          lessThan(layout.channelListRect!.left),
        );
        expect(layout.channelListRect!.right, lessThan(layout.playerRect.left));
        _expectBoundedAndSeparated(
          layout,
          const Rect.fromLTWH(10, 20, 1200, 720),
        );
      },
    );

    test(
      'expanded category closure removes its gap and expands the player',
      () {
        final open = LiveCompositionGeometry.calculate(
          contentBounds: const Rect.fromLTWH(0, 0, 1200, 720),
          categoryPanelExpanded: true,
        );
        final closed = LiveCompositionGeometry.calculate(
          contentBounds: const Rect.fromLTWH(0, 0, 1200, 720),
          categoryPanelExpanded: false,
        );

        expect(open.categoryRect, isNotNull);
        expect(closed.categoryRect, isNull);
        expect(closed.channelListRect!.left, 0);
        expect(
          closed.playerRect.left,
          closed.channelListRect!.right + LiveCompositionMetrics.panelGap,
        );
        expect(closed.playerRect.width, greaterThan(open.playerRect.width));
        _expectBoundedAndSeparated(
          closed,
          const Rect.fromLTWH(0, 0, 1200, 720),
        );
      },
    );

    test('covers all independent category and sender pane states', () {
      for (final categoryExpanded in [true, false]) {
        for (final channelExpanded in [true, false]) {
          final layout = LiveCompositionGeometry.calculate(
            contentBounds: const Rect.fromLTWH(0, 0, 1200, 720),
            categoryPanelExpanded: categoryExpanded,
            channelListExpanded: channelExpanded,
          );

          expect(layout.categoryRect != null, categoryExpanded);
          expect(
            layout.channelListRect!.width,
            channelExpanded
                ? LiveCompositionMetrics.senderExpandedWidth
                : LiveCompositionMetrics.channelRailWidth,
          );
          final categoryRight = categoryExpanded
              ? LiveCompositionMetrics.categoryPanelWidth +
                    LiveCompositionMetrics.panelGap
              : 0.0;
          expect(layout.channelListRect!.left, categoryRight);
          expect(
            layout.playerRect.left,
            layout.channelListRect!.right + LiveCompositionMetrics.panelGap,
          );
          _expectBoundedAndSeparated(
            layout,
            const Rect.fromLTWH(0, 0, 1200, 720),
          );
        }
      }
    });

    test('exposes the D11 pane geometry tokens from one source', () {
      expect(LiveCompositionMetrics.shellSidebarCollapsedWidth, 80);
      expect(LiveCompositionMetrics.shellSidebarExpandedWidth, 256);
      expect(LiveCompositionMetrics.channelRailWidth, 64);
      expect(LiveCompositionMetrics.panelGap, 16);
      expect(LiveCompositionMetrics.categoryPanelWidth, 232);
      expect(LiveCompositionMetrics.senderMediumWidth, 336);
      expect(LiveCompositionMetrics.senderExpandedWidth, 376);
      expect(LiveCompositionMetrics.senderWideWidth, 400);
      expect(LiveCompositionMetrics.panePadding, 16);
    });

    test('wide preserves the three columns and widens the channel list', () {
      final expanded = LiveCompositionGeometry.calculate(
        contentBounds: const Rect.fromLTWH(0, 0, 1200, 720),
      );
      final wide = LiveCompositionGeometry.calculate(
        contentBounds: const Rect.fromLTWH(0, 0, 1600, 720),
      );

      expect(wide.mode, LiveCompositionMode.wide);
      expect(wide.categoryRect!.right, lessThan(wide.channelListRect!.left));
      expect(wide.channelListRect!.right, lessThan(wide.playerRect.left));
      expect(
        wide.channelListRect!.width,
        greaterThanOrEqualTo(expanded.channelListRect!.width),
      );
      expect(wide.channelListRect!.width, lessThanOrEqualTo(400));
      _expectBoundedAndSeparated(wide, const Rect.fromLTWH(0, 0, 1600, 720));
    });

    test('keeps narrow and short bounds safe', () {
      for (final bounds in [
        const Rect.fromLTWH(5, 7, 40, 20),
        const Rect.fromLTWH(5, 7, 40, 5),
        const Rect.fromLTWH(5, 7, 40, 0),
      ]) {
        final layout = LiveCompositionGeometry.calculate(contentBounds: bounds);

        expect(layout.playerRect.width, greaterThanOrEqualTo(0));
        expect(layout.playerRect.height, greaterThanOrEqualTo(0));
        if (layout.channelListRect case final channelListRect?) {
          expect(channelListRect.width, greaterThanOrEqualTo(0));
          expect(channelListRect.height, greaterThanOrEqualTo(0));
        }
        _expectBoundedAndSeparated(layout, bounds);
      }
    });
  });

  group('LiveCompositionGeometry immersive layout', () {
    test(
      'uses the complete input viewport independently of responsive mode',
      () {
        for (final bounds in [
          const Rect.fromLTWH(0, 0, 719, 400),
          const Rect.fromLTWH(40, 30, 1600, 900),
        ]) {
          final layout = LiveCompositionGeometry.calculate(
            contentBounds: bounds,
            immersive: true,
          );

          expect(layout.immersive, isTrue);
          expect(layout.playerRect, bounds);
          expect(layout.channelListRect, isNull);
          expect(layout.categoryRect, isNull);
        }
      },
    );
  });
}

void _expectBoundedAndSeparated(LiveCompositionLayout layout, Rect bounds) {
  final rects = <Rect?>[
    layout.playerRect,
    layout.channelListRect,
    layout.categoryRect,
  ].whereType<Rect>().toList();

  for (final rect in rects) {
    expect(rect.left, greaterThanOrEqualTo(bounds.left));
    expect(rect.top, greaterThanOrEqualTo(bounds.top));
    expect(rect.right, lessThanOrEqualTo(bounds.right));
    expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
  }

  for (var index = 0; index < rects.length; index++) {
    for (var other = index + 1; other < rects.length; other++) {
      expect(rects[index].overlaps(rects[other]), isFalse);
    }
  }
}
