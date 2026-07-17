import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';

void main() {
  group('LiveLayoutMetrics.playerRect', () {
    test('immersive rect fills available space', () {
      const size = Size(1280, 768);
      final rect = LiveLayoutMetrics.playerRect(
        maxWidth: size.width,
        maxHeight: size.height,
        immersive: true,
      );

      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.width, size.width);
      expect(rect.height, size.height);
    });

    test('windowed rect sits below header and right of sidebar', () {
      const size = Size(1280, 768);
      final rect = LiveLayoutMetrics.playerRect(
        maxWidth: size.width,
        maxHeight: size.height,
        immersive: false,
      );

      expect(
        rect.left,
        greaterThan(LiveLayoutMetrics.sidebarWidthFor(expanded: false)),
      );
      expect(rect.top, LiveLayoutMetrics.headerTopOffset());
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
    });

    test('player slot uses the wider live layout without a log column', () {
      const size = Size(1280, 768);
      final category = LiveLayoutMetrics.windowedCategoryPanelRect(
        maxWidth: size.width,
        maxHeight: size.height,
      );
      final player = LiveLayoutMetrics.windowedPlayerRect(
        maxWidth: size.width,
        maxHeight: size.height,
      );

      expect(player.right, lessThan(category.left));
      expect(player.width, greaterThan(0));
      expect(category.right, lessThanOrEqualTo(size.width));
    });

    test('expanded sidebar reserves more room for the live shell', () {
      const size = Size(1280, 768);
      final compactPlayer = LiveLayoutMetrics.windowedPlayerRect(
        maxWidth: size.width,
        maxHeight: size.height,
      );
      final expandedPlayer = LiveLayoutMetrics.windowedPlayerRect(
        maxWidth: size.width,
        maxHeight: size.height,
        sidebarExpanded: true,
      );

      expect(expandedPlayer.left, greaterThan(compactPlayer.left));
      expect(expandedPlayer.width, lessThan(compactPlayer.width));
    });

    test('sidebar width follows the current shell source', () {
      expect(
        LiveLayoutMetrics.sidebarWidthFor(expanded: false),
        shellSidebarWidth(false),
      );
      expect(
        LiveLayoutMetrics.sidebarWidthFor(expanded: true),
        shellSidebarWidth(true),
      );
    });

    test('windowed rects remain bounded and separated on desktop sizes', () {
      const sizes = [Size(1024, 640), Size(1280, 768), Size(1920, 1080)];

      for (final size in sizes) {
        for (final expanded in [false, true]) {
          final viewport = Offset.zero & size;
          final player = LiveLayoutMetrics.windowedPlayerRect(
            maxWidth: size.width,
            maxHeight: size.height,
            sidebarExpanded: expanded,
          );
          final category = LiveLayoutMetrics.windowedCategoryPanelRect(
            maxWidth: size.width,
            maxHeight: size.height,
            sidebarExpanded: expanded,
          );

          expect(viewport.contains(player.topLeft), isTrue);
          expect(player.right, lessThanOrEqualTo(viewport.right));
          expect(player.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(viewport.contains(category.topLeft), isTrue);
          expect(category.right, lessThanOrEqualTo(viewport.right));
          expect(category.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(player.overlaps(category), isFalse);
        }
      }
    });

    test('immersive helper and player rect return the same viewport', () {
      const size = Size(1600, 900);
      final immersive = LiveLayoutMetrics.immersivePlayerRect(
        maxWidth: size.width,
        maxHeight: size.height,
      );
      final player = LiveLayoutMetrics.playerRect(
        maxWidth: size.width,
        maxHeight: size.height,
        immersive: true,
        sidebarExpanded: true,
      );

      expect(immersive, Offset.zero & size);
      expect(player, immersive);
    });
  });

  group('LiveHeaderLayoutMetrics', () {
    test('lifts the visible header while preserving the body top', () {
      const headerHeight = 168.0;
      final placement = LiveHeaderPlacementMetrics.resolve(
        headerHeight: headerHeight,
      );

      expect(
        placement.top,
        LiveLayoutMetrics.outerPadding - LiveHeaderPlacementMetrics.opticalLift,
      );
      expect(
        placement.height,
        headerHeight + LiveHeaderPlacementMetrics.opticalLift,
      );
      expect(
        placement.bodyTop,
        LiveLayoutMetrics.headerTopOffset(headerHeight: headerHeight),
      );
      expect(placement.top + placement.height, placement.bodyTop);
    });

    test('preserves the default 56 px inline header contract', () {
      final layout = LiveHeaderLayoutMetrics.resolve(
        availableWidth: 1200,
        textScaleFactor: 1,
      );

      expect(layout.arrangement, LiveHeaderArrangement.inline);
      expect(layout.height, LiveLayoutMetrics.headerBlockHeight);
      expect(
        LiveLayoutMetrics.headerTopOffset(headerHeight: layout.height),
        LiveLayoutMetrics.outerPadding + layout.height,
      );
    });

    test('stacks a narrow 200 percent header with deterministic height', () {
      final layout = LiveHeaderLayoutMetrics.resolve(
        availableWidth: 1199,
        textScaleFactor: 2,
      );

      expect(layout.arrangement, LiveHeaderArrangement.stacked);
      expect(layout.textBlockHeight, 100);
      expect(layout.height, 168);
    });

    test('keeps a wide 200 percent header inline', () {
      final layout = LiveHeaderLayoutMetrics.resolve(
        availableWidth: 1200,
        textScaleFactor: 2,
      );

      expect(layout.arrangement, LiveHeaderArrangement.inline);
      expect(layout.height, 144);
    });

    test(
      'expanded sidebar feeds its actual remaining width into the policy',
      () {
        const availableWidth = 719.0;
        final totalWidth =
            LiveLayoutMetrics.sidebarWidthFor(expanded: true) +
            (LiveLayoutMetrics.outerPadding * 2) +
            availableWidth;
        final resolvedWidth = LiveLayoutMetrics.liveColumnWidth(
          totalWidth,
          sidebarExpanded: true,
        );
        final layout = LiveHeaderLayoutMetrics.resolve(
          availableWidth: resolvedWidth,
          textScaleFactor: 2,
        );

        expect(resolvedWidth, availableWidth);
        expect(layout.arrangement, LiveHeaderArrangement.stacked);
        expect(layout.height, 168);
      },
    );
  });
}
