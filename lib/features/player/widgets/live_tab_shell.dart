import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m3uxtream_player/app/shell/shell_sidebar.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/core/services/live_composition_geometry.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_list_panel.dart';
import 'package:m3uxtream_player/features/channels/widgets/live_category_sidebar.dart';
import 'package:m3uxtream_player/features/player/widgets/player_panel.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_edge_handle.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';

/// Live tab shell â€” keeps a single [PlayerPanel] mounted; chrome layers around it.
class LiveTabShell extends StatefulWidget {
  const LiveTabShell({
    super.key,
    required this.immersive,
    required this.playerPanelKey,
    required this.activeSidebarIndex,
    required this.debugModeEnabled,
    required this.sidebarExpanded,
    required this.onSidebarTap,
    required this.onSidebarToggle,
    required this.headerTitle,
    required this.headerSubtitle,
    this.headerExtras,
    this.onToggleFullscreen,
  });

  static const layoutTransitionDuration = Duration(milliseconds: 280);
  static const headerKey = ValueKey<String>('live-tab-header');

  final bool immersive;
  final GlobalKey playerPanelKey;
  final int activeSidebarIndex;
  final bool debugModeEnabled;
  final bool sidebarExpanded;
  final ValueChanged<int> onSidebarTap;
  final VoidCallback onSidebarToggle;
  final String headerTitle;
  final String headerSubtitle;
  final Widget? headerExtras;
  final VoidCallback? onToggleFullscreen;

  @override
  State<LiveTabShell> createState() => _LiveTabShellState();
}

class _LiveTabShellState extends State<LiveTabShell> {
  bool _channelListExpanded = true;
  bool _categoryPanelExpanded = true;
  final FocusNode _channelListToggleFocusNode = FocusNode(
    debugLabel: 'LiveChannelListToggle',
  );
  final FocusNode _categoryToggleFocusNode = FocusNode(
    debugLabel: 'LiveCategoryToggle',
  );

  @override
  void dispose() {
    _channelListToggleFocusNode.dispose();
    _categoryToggleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final headerLayout = _headerLayout(context, constraints);
        final headerPlacement = LiveHeaderPlacementMetrics.resolve(
          headerHeight: headerLayout.height,
        );
        final contentBounds = _liveContentBounds(
          constraints,
          headerPlacement: headerPlacement,
        );
        final composition = LiveCompositionGeometry.calculate(
          contentBounds: contentBounds,
          immersive: widget.immersive,
          channelListExpanded: _channelListExpanded,
          categoryPanelExpanded: _categoryPanelExpanded,
        );

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            AnimatedPositioned(
              duration: LiveTabShell.layoutTransitionDuration,
              curve: Curves.easeOutCubic,
              left: composition.playerRect.left,
              top: composition.playerRect.top,
              width: composition.playerRect.width,
              height: composition.playerRect.height,
              child: PlayerPanel(
                key: widget.playerPanelKey,
                immersive: widget.immersive,
                onToggleFullscreen: widget.onToggleFullscreen,
              ),
            ),
            if (!widget.immersive)
              ..._windowedChrome(
                context: context,
                composition: composition,
                headerPlacement: headerPlacement,
              ),
            if (!widget.immersive) ..._paneEdgeHandles(context, composition),
          ],
        );
      },
    );
  }

  List<Widget> _windowedChrome({
    required BuildContext context,
    required LiveCompositionLayout composition,
    required LiveHeaderPlacementMetrics headerPlacement,
  }) {
    final sidebarWidth = LiveLayoutMetrics.sidebarWidthFor(
      expanded: widget.sidebarExpanded,
    );
    final channelListRect = composition.channelListRect;

    return [
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: sidebarWidth,
        child: ShellSidebar(
          activeIndex: widget.activeSidebarIndex,
          debugModeEnabled: widget.debugModeEnabled,
          isExpanded: widget.sidebarExpanded,
          onToggleExpanded: widget.onSidebarToggle,
          onTap: widget.onSidebarTap,
        ),
      ),
      Positioned(
        left: sidebarWidth + LiveLayoutMetrics.outerPadding,
        top: headerPlacement.top,
        right: LiveLayoutMetrics.outerPadding,
        height: headerPlacement.height,
        child: _Header(
          key: LiveTabShell.headerKey,
          title: widget.headerTitle,
          subtitle: widget.headerSubtitle,
          extras: widget.headerExtras,
          searchOpticalLift: LiveHeaderPlacementMetrics.opticalLift,
        ),
      ),
      if (channelListRect case final rect?)
        _animatedPanel(
          rect: rect,
          child: _ChannelListChrome(
            collapsed:
                !_channelListExpanded &&
                composition.mode != LiveCompositionMode.compact,
            onToggle: _toggleChannelList,
            focusNode: _channelListToggleFocusNode,
            onOpenCompactSheet: composition.mode == LiveCompositionMode.compact
                ? () => _openCompactChannelSheet(context)
                : null,
          ),
        ),
      if (channelListRect == null &&
          composition.mode == LiveCompositionMode.compact)
        Positioned(
          left: composition.playerRect.left + 12,
          top: composition.playerRect.top + 12,
          child: _ChannelListRail(
            onPressed: () => _openCompactChannelSheet(context),
            focusNode: _channelListToggleFocusNode,
          ),
        ),
      if (composition.mode == LiveCompositionMode.expanded ||
          composition.mode == LiveCompositionMode.wide)
        _animatedCategoryPanel(composition),
    ];
  }

  LiveHeaderLayoutMetrics _headerLayout(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    if (widget.immersive) {
      return LiveHeaderLayoutMetrics.resolve(
        availableWidth: constraints.maxWidth,
        textScaleFactor: 1,
      );
    }

    final availableWidth = LiveLayoutMetrics.liveColumnWidth(
      constraints.maxWidth,
      sidebarExpanded: widget.sidebarExpanded,
    );
    return LiveHeaderLayoutMetrics.resolve(
      availableWidth: availableWidth,
      textScaleFactor: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  Rect _liveContentBounds(
    BoxConstraints constraints, {
    required LiveHeaderPlacementMetrics headerPlacement,
  }) {
    if (widget.immersive) {
      return Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
    }

    final sidebarWidth = LiveLayoutMetrics.sidebarWidthFor(
      expanded: widget.sidebarExpanded,
    );
    final left = sidebarWidth + LiveLayoutMetrics.outerPadding;
    final top = headerPlacement.bodyTop;
    return Rect.fromLTWH(
      left,
      top,
      math.max(0, constraints.maxWidth - left - LiveLayoutMetrics.outerPadding),
      math.max(0, constraints.maxHeight - top - LiveLayoutMetrics.outerPadding),
    );
  }

  List<Widget> _paneEdgeHandles(
    BuildContext context,
    LiveCompositionLayout composition,
  ) {
    final channelRect = composition.channelListRect;
    final handles = <Widget>[];
    final categoryIsEmbedded =
        composition.mode == LiveCompositionMode.expanded ||
        composition.mode == LiveCompositionMode.wide;

    // Categories remain reachable after the responsive composition removes
    // their fixed pane. At medium/compact widths the same seam action opens a
    // modal Material surface instead of squeezing the video into a third
    // column.
    if (categoryIsEmbedded) {
      final categoryRect = composition.categoryRect;
      final embeddedChannelRect = channelRect!;
      final categorySeamX = categoryRect == null
          ? embeddedChannelRect.left
          : (categoryRect.right + embeddedChannelRect.left) / 2;
      handles.add(
        _animatedEdgeHandle(
          key: const ValueKey('live-category-edge-handle'),
          left: categorySeamX - M3PaneEdgeHandle.hitWidth / 2,
          top: embeddedChannelRect.center.dy - M3PaneEdgeHandle.hitHeight / 2,
          target: M3PaneTarget.categories,
          expanded: categoryRect != null,
          onPressed: _toggleCategoryPanel,
          focusNode: _categoryToggleFocusNode,
        ),
      );
    } else {
      final anchorRect = channelRect ?? composition.playerRect;
      handles.add(
        _animatedEdgeHandle(
          key: const ValueKey('live-category-edge-handle'),
          left: anchorRect.left - M3PaneEdgeHandle.hitWidth / 2,
          top: anchorRect.center.dy - M3PaneEdgeHandle.hitHeight / 2,
          target: M3PaneTarget.categories,
          expanded: false,
          onPressed: () => _openCompactCategorySheet(context),
          focusNode: _categoryToggleFocusNode,
        ),
      );
    }

    if (channelRect == null) return handles;

    final senderIsExpanded =
        channelRect.width > LiveCompositionMetrics.channelRailWidth;
    final senderSeamX = (channelRect.right + composition.playerRect.left) / 2;
    handles.add(
      _animatedEdgeHandle(
        key: const ValueKey('live-channel-edge-handle'),
        left: senderSeamX - M3PaneEdgeHandle.hitWidth / 2,
        top: composition.playerRect.center.dy - M3PaneEdgeHandle.hitHeight / 2,
        target: M3PaneTarget.channels,
        expanded: senderIsExpanded,
        onPressed: _toggleChannelList,
        focusNode: _channelListToggleFocusNode,
      ),
    );
    return handles;
  }

  Widget _animatedEdgeHandle({
    required Key key,
    required double left,
    required double top,
    required M3PaneTarget target,
    required bool expanded,
    required VoidCallback onPressed,
    required FocusNode focusNode,
  }) {
    return AnimatedPositioned(
      key: key,
      duration: LiveTabShell.layoutTransitionDuration,
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: M3PaneEdgeHandle.hitWidth,
      height: M3PaneEdgeHandle.hitHeight,
      child: M3PaneEdgeHandle(
        target: target,
        expanded: expanded,
        onPressed: onPressed,
        focusNode: focusNode,
      ),
    );
  }

  static Widget _animatedPanel({required Rect rect, required Widget child}) {
    return AnimatedPositioned(
      duration: LiveTabShell.layoutTransitionDuration,
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }

  static Widget _animatedCategoryPanel(LiveCompositionLayout composition) {
    final channelRect = composition.channelListRect!;
    final expandedRect = composition.categoryRect;
    final rect =
        expandedRect ??
        Rect.fromLTWH(
          channelRect.left,
          channelRect.top,
          LiveCompositionMetrics.categoryPanelWidth,
          channelRect.height,
        );
    return AnimatedPositioned(
      key: const ValueKey('live-category-pane-transition'),
      duration: LiveTabShell.layoutTransitionDuration,
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: _CategoryPaneTransition(expanded: expandedRect != null),
    );
  }

  void _toggleChannelList() {
    setState(() => _channelListExpanded = !_channelListExpanded);
  }

  void _toggleCategoryPanel() {
    setState(() => _categoryPanelExpanded = !_categoryPanelExpanded);
  }

  Future<void> _openCompactChannelSheet(BuildContext context) async {
    setState(() => _channelListExpanded = false);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 460,
          child: ChannelListPanel(
            headerActions: M3PaneToggleButton(
              target: M3PaneTarget.channels,
              expanded: true,
              onPressed: () => Navigator.of(context).pop(),
              focusNode: _channelListToggleFocusNode,
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _channelListExpanded = true);
  }

  Future<void> _openCompactCategorySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 460,
            child: LiveCategorySidebar(
              width: double.infinity,
              headerActions: M3PaneToggleButton(
                target: M3PaneTarget.categories,
                expanded: true,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the category surface at its valid full layout width and animates only
/// its reveal clip. This avoids squeezed rows and the abrupt mount/unmount jump
/// that previously disagreed with the moving neighbouring panes.
class _CategoryPaneTransition extends StatefulWidget {
  const _CategoryPaneTransition({required this.expanded});

  final bool expanded;

  @override
  State<_CategoryPaneTransition> createState() =>
      _CategoryPaneTransitionState();
}

class _CategoryPaneTransitionState extends State<_CategoryPaneTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LiveTabShell.layoutTransitionDuration,
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _CategoryPaneTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    _controller.animateTo(widget.expanded ? 1 : 0, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.expanded,
      child: ExcludeSemantics(
        excluding: !widget.expanded,
        child: AnimatedBuilder(
          animation: _controller,
          child: const LiveCategorySidebar(
            width: LiveCompositionMetrics.categoryPanelWidth,
          ),
          builder: (context, child) => ClipRect(
            clipper: _HorizontalRevealClipper(_controller.value),
            child: Opacity(
              key: const ValueKey('live-category-pane-opacity'),
              opacity: _controller.value,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizontalRevealClipper extends CustomClipper<Rect> {
  const _HorizontalRevealClipper(this.factor);

  final double factor;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * factor, size.height);

  @override
  bool shouldReclip(covariant _HorizontalRevealClipper oldClipper) =>
      factor != oldClipper.factor;
}

class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.title,
    required this.subtitle,
    required this.extras,
    required this.searchOpticalLift,
  });

  final String title;
  final String subtitle;
  final Widget? extras;
  final double searchOpticalLift;

  @override
  Widget build(BuildContext context) {
    return ShellCommandArea(
      title: title,
      supportingText: subtitle,
      search: extras,
      leadingOpticalInset: searchOpticalLift,
    );
  }
}

class _ChannelListChrome extends StatelessWidget {
  const _ChannelListChrome({
    required this.collapsed,
    required this.onToggle,
    required this.focusNode,
    this.onOpenCompactSheet,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final FocusNode focusNode;
  final VoidCallback? onOpenCompactSheet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // During the expand animation the panel receives the final child
        // immediately, while its width is still close to the 56 px rail. Keep
        // the rail until the content has enough room for its list rows.
        final showExpanded =
            !collapsed &&
            constraints.maxWidth >=
                LiveLayoutMetrics.minimumChannelPanelOuterWidth;
        if (!showExpanded) {
          return _ChannelListRail(
            onPressed: onOpenCompactSheet ?? onToggle,
            focusNode: focusNode,
            showTrigger: false,
          );
        }

        return const ChannelListPanel();
      },
    );
  }
}

class _ChannelListRail extends StatelessWidget {
  const _ChannelListRail({
    required this.onPressed,
    required this.focusNode,
    this.showTrigger = true,
  });

  final VoidCallback onPressed;
  final FocusNode focusNode;
  final bool showTrigger;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.low,
      elevation: AppElevation.level1,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTrigger)
              M3PaneToggleButton(
                target: M3PaneTarget.channels,
                expanded: false,
                onPressed: onPressed,
                focusNode: focusNode,
                showLabel: false,
              ),
          ],
        ),
      ),
    );
  }
}
