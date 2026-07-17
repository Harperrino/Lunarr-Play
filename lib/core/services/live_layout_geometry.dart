import 'dart:math' as math;
import 'dart:ui';

import 'live_composition_geometry.dart';

/// Layout constants matching the Live tab shell.
class LiveLayoutMetrics {
  static const outerPadding = LiveCompositionMetrics.shellOuterPadding;
  static const headerBlockHeight = LiveCompositionMetrics.headerBlockHeight;
  static const headerCommandAreaHeight = headerBlockHeight;
  static const headerCommandAreaScaledHeight = 72.0;
  static const headerTitleSearchGap = 12.0;
  static const headerBottomGap = LiveCompositionMetrics.headerBottomGap;
  static const columnGap = LiveCompositionMetrics.panelGap;
  static const categoryPanelWidth = LiveCompositionMetrics.categoryPanelWidth;
  static const minimumChannelListContentWidth =
      LiveCompositionMetrics.minimumChannelListContentWidth;
  static const minimumChannelPanelOuterWidth =
      LiveCompositionMetrics.minimumChannelPanelOuterWidth;
  static const playerFlex = LiveCompositionMetrics.playerFlex;
  static const channelListFlex = LiveCompositionMetrics.channelListFlex;

  static double sidebarWidthFor({required bool expanded}) {
    return expanded
        ? LiveCompositionMetrics.shellSidebarExpandedWidth
        : LiveCompositionMetrics.shellSidebarCollapsedWidth;
  }

  static double headerTopOffset({double headerHeight = headerBlockHeight}) =>
      headerHeight + headerBottomGap;

  static double _contentWidth(
    double maxWidth, {
    bool sidebarExpanded = false,
  }) => math.max(
    0,
    maxWidth - sidebarWidthFor(expanded: sidebarExpanded) - (outerPadding * 2),
  );

  static double liveColumnWidth(
    double maxWidth, {
    bool sidebarExpanded = false,
  }) => _contentWidth(maxWidth, sidebarExpanded: sidebarExpanded);

  static double _columnBodyHeight(double maxHeight) {
    final contentHeight = maxHeight - headerTopOffset() - outerPadding;
    return math.max(0, contentHeight - outerPadding);
  }

  static double playerSlotWidth(
    double maxWidth, {
    bool sidebarExpanded = false,
  }) => math.max(
    0,
    liveColumnWidth(maxWidth, sidebarExpanded: sidebarExpanded) -
        categoryPanelWidth -
        columnGap,
  );

  static double _playerSlotWidth(
    double maxWidth, {
    bool sidebarExpanded = false,
  }) => playerSlotWidth(maxWidth, sidebarExpanded: sidebarExpanded);

  /// Player slot in windowed Live layout (left of category panel).
  static Rect windowedPlayerRect({
    required double maxWidth,
    required double maxHeight,
    bool sidebarExpanded = false,
  }) {
    final playerWidth = _playerSlotWidth(
      maxWidth,
      sidebarExpanded: sidebarExpanded,
    );
    final columnBodyHeight = _columnBodyHeight(maxHeight);
    final playerHeight = math.max(
      0.0,
      (columnBodyHeight - columnGap) *
          playerFlex /
          (playerFlex + channelListFlex),
    );

    return Rect.fromLTWH(
      sidebarWidthFor(expanded: sidebarExpanded) + outerPadding,
      headerTopOffset(),
      playerWidth,
      playerHeight,
    );
  }

  /// Category panel — full column height, right of player.
  static Rect windowedCategoryPanelRect({
    required double maxWidth,
    required double maxHeight,
    bool sidebarExpanded = false,
  }) {
    final player = windowedPlayerRect(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      sidebarExpanded: sidebarExpanded,
    );
    return Rect.fromLTWH(
      player.right + columnGap,
      headerTopOffset(),
      categoryPanelWidth,
      _columnBodyHeight(maxHeight),
    );
  }

  static Rect immersivePlayerRect({
    required double maxWidth,
    required double maxHeight,
  }) {
    return Rect.fromLTWH(0, 0, maxWidth, maxHeight);
  }

  static Rect playerRect({
    required double maxWidth,
    required double maxHeight,
    required bool immersive,
    bool sidebarExpanded = false,
  }) {
    return immersive
        ? immersivePlayerRect(maxWidth: maxWidth, maxHeight: maxHeight)
        : windowedPlayerRect(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            sidebarExpanded: sidebarExpanded,
          );
  }
}

/// Explicit placement contract for the visible Live header and the body
/// below it.
///
/// The optical lift moves the search carrier upward. The visible title/action
/// baseline is restored inside [ShellCommandArea], while the increased header
/// height keeps the body top on the established Live composition geometry.
class LiveHeaderPlacementMetrics {
  const LiveHeaderPlacementMetrics._({
    required this.top,
    required this.height,
    required this.bodyTop,
  });

  static const opticalLift = 4.0;

  final double top;
  final double height;
  final double bodyTop;

  static LiveHeaderPlacementMetrics resolve({required double headerHeight}) {
    final top = LiveLayoutMetrics.outerPadding - opticalLift;
    final height = headerHeight + opticalLift;
    return LiveHeaderPlacementMetrics._(
      top: top,
      height: height,
      bodyTop: top + height,
    );
  }
}

enum LiveHeaderArrangement { inline, stacked }

/// Pure presentation policy for the windowed Live header.
///
/// It preserves the compact 56 px header at the default text scale. Larger
/// text receives the line height it needs, while narrow headers stack their
/// command area below the title block instead of squeezing either region.
class LiveHeaderLayoutMetrics {
  const LiveHeaderLayoutMetrics._({
    required this.arrangement,
    required this.height,
    required this.textBlockHeight,
  });

  static const _titleLineHeight = 28.0;
  static const _subtitleLineHeight = 20.0;
  static const _titleSubtitleGap = 4.0;
  // Keep the shared command area's 720 px compact breakpoint at normal scale,
  // while retaining the existing 600 px scaled inline contract at 200 %.
  static const _minimumInlineWidthAtDefaultScale = 600.0;
  static const _compactHeaderWidth = 720.0;

  final LiveHeaderArrangement arrangement;
  final double height;
  final double textBlockHeight;

  bool get isStacked => arrangement == LiveHeaderArrangement.stacked;

  static LiveHeaderLayoutMetrics resolve({
    required double availableWidth,
    required double textScaleFactor,
  }) {
    final effectiveScale = math.max(1.0, textScaleFactor);
    final textBlockHeight =
        ((_titleLineHeight + _subtitleLineHeight) * effectiveScale) +
        _titleSubtitleGap;
    final minimumInlineWidth = math.max(
      _compactHeaderWidth,
      _minimumInlineWidthAtDefaultScale * effectiveScale,
    );
    final isStacked = availableWidth < minimumInlineWidth;
    final inlineHeight = effectiveScale > 1.0
        ? LiveLayoutMetrics.headerCommandAreaScaledHeight * effectiveScale
        : LiveLayoutMetrics.headerCommandAreaHeight;
    final height = isStacked
        ? textBlockHeight +
              LiveLayoutMetrics.headerTitleSearchGap +
              LiveLayoutMetrics.headerCommandAreaHeight
        : math.max(inlineHeight, textBlockHeight);

    return LiveHeaderLayoutMetrics._(
      arrangement: isStacked
          ? LiveHeaderArrangement.stacked
          : LiveHeaderArrangement.inline,
      height: height,
      textBlockHeight: textBlockHeight,
    );
  }
}
