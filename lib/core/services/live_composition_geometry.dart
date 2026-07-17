import 'dart:math' as math;
import 'dart:ui';

/// The responsive variants used by the future Live widget composition.
enum LiveCompositionMode { compact, medium, expanded, wide }

/// Single source of truth for the Live composition's pane geometry.
abstract final class LiveCompositionMetrics {
  static const compactBreakpoint = 720.0;
  static const expandedBreakpoint = 1200.0;
  static const wideBreakpoint = 1600.0;

  static const shellSidebarCollapsedWidth = 80.0;
  static const shellSidebarExpandedWidth = 256.0;
  static const shellOuterPadding = 24.0;
  static const headerBlockHeight = 56.0;
  static const headerBottomGap = 24.0;
  static const channelRailWidth = 64.0;
  static const panelGap = 16.0;
  static const categoryPanelWidth = 232.0;
  static const senderMediumWidth = 336.0;
  static const senderExpandedWidth = 376.0;
  static const senderWideWidth = 400.0;
  static const panePadding = 16.0;
  static const minimumChannelListContentWidth = 280.0;
  // The full sender pane must reserve its fixed header controls before it is
  // mounted during a width animation. Keep this contract in geometry so the
  // chrome and the panel cannot disagree about when the rail is safe.
  static const channelPanelHeaderActionSlotCount = 3;
  static const channelPanelHeaderActionHitTarget = 48.0;
  static const channelPanelHeaderActionGap = 4.0;
  static const channelPanelHeaderActionsWidth =
      (channelPanelHeaderActionSlotCount * channelPanelHeaderActionHitTarget) +
      ((channelPanelHeaderActionSlotCount - 1) * channelPanelHeaderActionGap);
  static const minimumChannelPanelInnerWidth =
      minimumChannelListContentWidth > channelPanelHeaderActionsWidth
      ? minimumChannelListContentWidth
      : channelPanelHeaderActionsWidth;
  static const minimumChannelPanelOuterWidth =
      minimumChannelPanelInnerWidth + (panePadding * 2);
  static const minimumPlayerWidth = 160.0;
  static const playerFlex = 3;
  static const channelListFlex = 2;
}

/// Pure, consumer-free geometry for the windowed and immersive Live layouts.
///
/// [contentBounds] is the already available content area. This intentionally
/// does not know about the shell, a [BuildContext], or any player widgets so
/// M5b can adopt it without changing Live state or playback behaviour.
class LiveCompositionGeometry {
  const LiveCompositionGeometry._();

  static const compactBreakpoint = LiveCompositionMetrics.compactBreakpoint;
  static const expandedBreakpoint = LiveCompositionMetrics.expandedBreakpoint;
  static const wideBreakpoint = LiveCompositionMetrics.wideBreakpoint;

  static LiveCompositionLayout calculate({
    required Rect contentBounds,
    bool immersive = false,
    bool channelListExpanded = true,
    bool categoryPanelExpanded = true,
  }) {
    final bounds = _normalized(contentBounds);
    final mode = modeForWidth(bounds.width);

    if (immersive) {
      return LiveCompositionLayout(
        mode: mode,
        playerRect: bounds,
        channelListRect: null,
        categoryRect: null,
        immersive: true,
        categoryPanelExpanded: false,
      );
    }

    return switch (mode) {
      LiveCompositionMode.compact => _compact(bounds),
      LiveCompositionMode.medium => _twoColumn(
        bounds,
        channelListExpanded: channelListExpanded,
      ),
      LiveCompositionMode.expanded => _threeColumn(
        bounds,
        channelWidth: LiveCompositionMetrics.senderExpandedWidth,
        channelListExpanded: channelListExpanded,
        categoryPanelExpanded: categoryPanelExpanded,
      ),
      LiveCompositionMode.wide => _threeColumn(
        bounds,
        channelWidth: LiveCompositionMetrics.senderWideWidth,
        channelListExpanded: channelListExpanded,
        categoryPanelExpanded: categoryPanelExpanded,
      ),
    };
  }

  static LiveCompositionMode modeForWidth(double width) {
    if (width < LiveCompositionMetrics.compactBreakpoint) {
      return LiveCompositionMode.compact;
    }
    if (width < LiveCompositionMetrics.expandedBreakpoint) {
      return LiveCompositionMode.medium;
    }
    if (width < LiveCompositionMetrics.wideBreakpoint) {
      return LiveCompositionMode.expanded;
    }
    return LiveCompositionMode.wide;
  }

  static LiveCompositionLayout _compact(Rect bounds) {
    return LiveCompositionLayout(
      mode: LiveCompositionMode.compact,
      playerRect: bounds,
      channelListRect: null,
      categoryRect: null,
      immersive: false,
      categoryPanelExpanded: false,
    );
  }

  static LiveCompositionLayout _twoColumn(
    Rect bounds, {
    required bool channelListExpanded,
  }) {
    final availableChannelWidth = math.max(
      0.0,
      bounds.width -
          LiveCompositionMetrics.panelGap -
          LiveCompositionMetrics.minimumPlayerWidth,
    );
    final channelWidth = _safeChannelWidth(
      requestedWidth: LiveCompositionMetrics.senderMediumWidth,
      availableWidth: availableChannelWidth,
      expanded: channelListExpanded,
    );
    final playerLeft =
        bounds.left + channelWidth + LiveCompositionMetrics.panelGap;

    return LiveCompositionLayout(
      mode: LiveCompositionMode.medium,
      playerRect: Rect.fromLTWH(
        playerLeft,
        bounds.top,
        math.max(0.0, bounds.right - playerLeft),
        bounds.height,
      ),
      channelListRect: Rect.fromLTWH(
        bounds.left,
        bounds.top,
        channelWidth,
        bounds.height,
      ),
      categoryRect: null,
      immersive: false,
      categoryPanelExpanded: false,
    );
  }

  static LiveCompositionLayout _threeColumn(
    Rect bounds, {
    required double channelWidth,
    required bool channelListExpanded,
    required bool categoryPanelExpanded,
  }) {
    final effectiveChannelWidth = channelListExpanded
        ? channelWidth
        : LiveCompositionMetrics.channelRailWidth;
    final categoryWidth = categoryPanelExpanded
        ? math.min(LiveCompositionMetrics.categoryPanelWidth, bounds.width)
        : 0.0;
    final afterCategory =
        bounds.left +
        categoryWidth +
        (categoryPanelExpanded ? LiveCompositionMetrics.panelGap : 0.0);
    final availableChannelWidth = math.max(
      0.0,
      bounds.right -
          afterCategory -
          LiveCompositionMetrics.panelGap -
          LiveCompositionMetrics.minimumPlayerWidth,
    );
    final safeChannelWidth = _safeChannelWidth(
      requestedWidth: effectiveChannelWidth,
      availableWidth: availableChannelWidth,
      expanded: channelListExpanded,
    );
    final playerLeft =
        afterCategory + safeChannelWidth + LiveCompositionMetrics.panelGap;

    return LiveCompositionLayout(
      mode: modeForWidth(bounds.width),
      playerRect: Rect.fromLTWH(
        playerLeft,
        bounds.top,
        math.max(0.0, bounds.right - playerLeft),
        bounds.height,
      ),
      channelListRect: Rect.fromLTWH(
        afterCategory,
        bounds.top,
        safeChannelWidth,
        bounds.height,
      ),
      categoryRect: categoryPanelExpanded
          ? Rect.fromLTWH(bounds.left, bounds.top, categoryWidth, bounds.height)
          : null,
      immersive: false,
      categoryPanelExpanded: categoryPanelExpanded,
    );
  }

  static Rect _normalized(Rect bounds) {
    final width = math.max(0.0, bounds.width);
    final height = math.max(0.0, bounds.height);
    return Rect.fromLTWH(bounds.left, bounds.top, width, height);
  }

  static double _safeChannelWidth({
    required double requestedWidth,
    required double availableWidth,
    required bool expanded,
  }) {
    if (!expanded) {
      return math.min(LiveCompositionMetrics.channelRailWidth, availableWidth);
    }

    // A panel narrower than the outer contract cannot guarantee its fixed
    // header hit targets. Keep the 64-dp rail in that intermediate state and
    // give the saved width back to the player.
    if (availableWidth < LiveCompositionMetrics.minimumChannelPanelOuterWidth) {
      return math.min(LiveCompositionMetrics.channelRailWidth, availableWidth);
    }
    return math.min(requestedWidth, availableWidth);
  }
}

/// Result of a [LiveCompositionGeometry.calculate] call.
class LiveCompositionLayout {
  const LiveCompositionLayout({
    required this.mode,
    required this.playerRect,
    required this.channelListRect,
    required this.categoryRect,
    required this.immersive,
    required this.categoryPanelExpanded,
  });

  final LiveCompositionMode mode;
  final Rect playerRect;
  final Rect? channelListRect;
  final Rect? categoryRect;
  final bool immersive;
  final bool categoryPanelExpanded;
}
