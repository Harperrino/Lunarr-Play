import 'package:flutter/material.dart';

import '../theme/app_component_metrics.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import 'app_surface_state_layer.dart';
import 'm3_slots.dart';

/// Selects the presentation family for a navigation item.
enum M3NavigationItemVisualRole {
  list,
  navigationRail,
  categoryNavigation,
  settingsNavigation,
}

/// A provider-free Material 3 navigation row shared by shell, category and
/// settings navigation.
///
/// The parent owns routing and selection. This widget owns only presentation,
/// pointer/focus state, keyboard activation and accessible semantics.
class M3NavigationItem extends StatefulWidget {
  const M3NavigationItem({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.expanded = true,
    this.height = 48,
    this.width,
    this.focusNode,
    this.tooltip,
    this.padding,
    this.shape,
    this.showTooltip = true,
    this.visualRole = M3NavigationItemVisualRole.list,
    this.focusOutlineKey,
    this.transitionDuration,
  }) : assert(icon != null || leading != null);

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool enabled;
  final bool expanded;
  final double height;
  final double? width;
  final FocusNode? focusNode;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final OutlinedBorder? shape;
  final bool showTooltip;
  final M3NavigationItemVisualRole visualRole;
  final Key? focusOutlineKey;
  final Duration? transitionDuration;

  @override
  State<M3NavigationItem> createState() => _M3NavigationItemState();
}

class _M3NavigationItemState extends State<M3NavigationItem> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  Set<WidgetState> get _states => {
    if (widget.selected) WidgetState.selected,
    if (!widget.enabled) WidgetState.disabled,
    if (_hovered) WidgetState.hovered,
    if (_focused) WidgetState.focused,
    if (_pressed) WidgetState.pressed,
  };

  void _setHovered(bool value) {
    if (_hovered != value && mounted) setState(() => _hovered = value);
  }

  void _setFocused(bool value) {
    if (_focused != value && mounted) setState(() => _focused = value);
  }

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final isNavigationRail =
        widget.visualRole == M3NavigationItemVisualRole.navigationRail;
    final isCategoryNavigation =
        widget.visualRole == M3NavigationItemVisualRole.categoryNavigation;
    final isSettingsNavigation =
        widget.visualRole == M3NavigationItemVisualRole.settingsNavigation;
    final isQuietNavigation = isCategoryNavigation || isSettingsNavigation;
    final navigationRailTheme = Theme.of(context).navigationRailTheme;
    final baseShape =
        widget.shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.large),
        );
    final railIndicatorShape = navigationRailTheme.indicatorShape;
    final itemShape = isNavigationRail && railIndicatorShape is OutlinedBorder
        ? railIndicatorShape
        : baseShape;
    final selectedIconForeground =
        navigationRailTheme.selectedIconTheme?.color ??
        colors.onSecondaryContainer;
    final unselectedIconForeground =
        navigationRailTheme.unselectedIconTheme?.color ??
        colors.onSurfaceVariant;
    final selectedLabelForeground =
        navigationRailTheme.selectedLabelTextStyle?.color ?? colors.onSurface;
    final unselectedLabelForeground =
        navigationRailTheme.unselectedLabelTextStyle?.color ??
        colors.onSurfaceVariant;
    final foreground = widget.selected
        ? (isNavigationRail
              ? selectedLabelForeground
              : isQuietNavigation
              ? colors.onSecondaryContainer
              : colors.onPrimaryContainer)
        : (isNavigationRail
              ? unselectedLabelForeground
              : colors.onSurfaceVariant);
    final iconForeground = isNavigationRail
        ? (widget.selected ? selectedIconForeground : unselectedIconForeground)
        : foreground;
    final contentPadding =
        widget.padding ??
        EdgeInsets.symmetric(horizontal: widget.expanded ? 12 : 0, vertical: 4);
    final borderRadius = itemShape is RoundedRectangleBorder
        ? itemShape.borderRadius
        : BorderRadius.circular(shapes.large);
    final surfaceColor =
        isNavigationRail || isCategoryNavigation || isSettingsNavigation
        ? Colors.transparent
        : widget.selected
        ? colors.primaryContainer
        : colors.surfaceContainerLow;
    final borderColor = widget.selected
        ? colors.primary
        : colors.outlineVariant.withValues(alpha: 0.65);
    final leading = M3LeadingSlot(
      icon: widget.leading == null ? widget.icon : null,
      foregroundColor: iconForeground,
      child: widget.leading,
    );
    final trailing = widget.trailing == null
        ? null
        : M3LeadingSlot(
            foregroundColor: iconForeground,
            child: widget.trailing,
          );

    Widget content = AnimatedContainer(
      width: widget.width,
      height: widget.height,
      duration: widget.transitionDuration ?? AppMotion.of(context).state,
      curve: AppMotion.of(context).standardCurve,
      decoration: isNavigationRail || isQuietNavigation
          ? null
          : BoxDecoration(
              color: surfaceColor,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: widget.selected
                    ? AppComponentMetrics.selectedOutlineWidth
                    : AppComponentMetrics.outlineWidth,
              ),
            ),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Semantics(
          container: true,
          button: true,
          enabled: widget.enabled ? null : false,
          selected: widget.selected,
          label: widget.label,
          onTap: widget.enabled ? widget.onPressed : null,
          excludeSemantics: true,
          child: AppSurfaceStateLayer(
            shape: itemShape,
            states: _states,
            surfaceColor: Colors.transparent,
            defaultForegroundColor: isNavigationRail || isQuietNavigation
                ? isQuietNavigation
                      ? colors.onSurfaceVariant
                      : unselectedIconForeground
                : null,
            selectedForegroundColor: isNavigationRail
                ? selectedIconForeground
                : isQuietNavigation
                ? colors.onSecondaryContainer
                : null,
            selectedSurfaceColor: isNavigationRail
                ? (navigationRailTheme.indicatorColor ??
                      colors.secondaryContainer)
                : isQuietNavigation
                ? colors.secondaryContainer
                : null,
            disabledSurfaceColor: isNavigationRail || isQuietNavigation
                ? Colors.transparent
                : null,
            focusOutlineKey: widget.focusOutlineKey,
            focusOutlineStyle: AppFocusOutlineStyle.box,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: widget.focusNode,
                canRequestFocus: widget.enabled,
                onTap: widget.enabled ? widget.onPressed : null,
                onFocusChange: _setFocused,
                onHover: (value) => _setHovered(widget.enabled && value),
                onHighlightChanged: _setPressed,
                customBorder: itemShape,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashColor: isNavigationRail || isQuietNavigation
                    ? Colors.transparent
                    : colors.primary.withValues(alpha: 0.12),
                child: Padding(
                  padding: contentPadding,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rowWidth =
                          constraints.maxWidth.isFinite &&
                              constraints.maxWidth >
                                  AppComponentMetrics.slotVisualSize
                          ? constraints.maxWidth
                          : AppComponentMetrics.slotVisualSize;
                      final rowHeight =
                          constraints.maxHeight.isFinite &&
                              constraints.maxHeight >
                                  AppComponentMetrics.slotVisualSize
                          ? constraints.maxHeight
                          : AppComponentMetrics.slotVisualSize;

                      return OverflowBox(
                        alignment: Alignment.center,
                        minWidth: rowWidth,
                        maxWidth: rowWidth,
                        minHeight: rowHeight,
                        maxHeight: rowHeight,
                        child: Row(
                          mainAxisAlignment: widget.expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            leading,
                            if (widget.expanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: foreground,
                                        fontWeight: widget.selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ),
                              if (trailing != null) ...[
                                const SizedBox(width: 8),
                                trailing,
                              ],
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.showTooltip) {
      content = Tooltip(
        message: widget.tooltip ?? widget.label,
        child: content,
      );
    }

    return AnimatedSize(
      duration: AppMotion.of(context).state,
      curve: AppMotion.of(context).standardCurve,
      child: content,
    );
  }
}

/// A titled, provider-free group for navigation items.
class M3NavigationSection extends StatelessWidget {
  const M3NavigationSection({
    super.key,
    required this.children,
    this.title,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.mainAxisSize = MainAxisSize.max,
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Text(
                title!,
                style: textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}
