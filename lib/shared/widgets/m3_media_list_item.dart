import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_elevation.dart';
import '../theme/app_motion.dart';
import '../theme/app_shapes.dart';
import 'app_surface.dart';
import 'm3_slots.dart';

/// Provider-free media/list row contract for channels, favourites and
/// catalogue metadata.
class M3MediaListItem extends StatefulWidget {
  const M3MediaListItem({
    super.key,
    required this.title,
    required this.onActivate,
    required this.leading,
    this.subtitle,
    this.metadata,
    this.badge,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.compact = false,
    this.semanticLabel,
    this.shape,
    this.padding,
    this.surfaceKey,
    this.surfaceLevel = AppSurfaceLevel.low,
    this.surfaceColor,
    this.elevation = AppElevation.level0,
  });

  final String title;
  final VoidCallback? onActivate;
  final Widget leading;
  final Widget? subtitle;
  final Widget? metadata;
  final Widget? badge;

  /// Use fixed-slot children (`M3LeadingSlot`/`M3ActionSlot`) or an explicit
  /// row of those children when more than one trailing action is needed.
  final Widget? trailing;
  final bool selected;
  final bool enabled;
  final bool compact;
  final String? semanticLabel;
  final OutlinedBorder? shape;
  final EdgeInsetsGeometry? padding;
  final Key? surfaceKey;

  /// Allows a consumer to keep list rows on the carrier's tonal plane.
  final AppSurfaceLevel surfaceLevel;

  /// Use transparent for rows that must not become nested cards.
  final Color? surfaceColor;
  final double elevation;

  @override
  State<M3MediaListItem> createState() => _M3MediaListItemState();
}

class _M3MediaListItemState extends State<M3MediaListItem> {
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

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onActivate?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final rowShape =
        widget.shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.large),
        );
    final foreground = widget.selected
        ? colors.onPrimaryContainer
        : colors.onSurface;
    final contentOpacity = widget.enabled ? 1.0 : 0.38;

    final content = Focus(
      canRequestFocus: widget.enabled,
      onFocusChange: (value) {
        if (mounted && _focused != value) setState(() => _focused = value);
      },
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) {
          if (mounted && widget.enabled && !_hovered) {
            setState(() => _hovered = true);
          }
        },
        onExit: (_) {
          if (mounted && _hovered) setState(() => _hovered = false);
        },
        child: Semantics(
          container: true,
          button: true,
          enabled: widget.enabled ? null : false,
          selected: widget.selected,
          label: widget.semanticLabel ?? widget.title,
          onTap: widget.enabled ? widget.onActivate : null,
          excludeSemantics: false,
          child: AppSurface(
            key: widget.surfaceKey,
            level: widget.surfaceLevel,
            surfaceColor: widget.surfaceColor,
            elevation: widget.elevation,
            shape: rowShape,
            states: _states,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                canRequestFocus: false,
                excludeFromSemantics: true,
                onTap: widget.enabled ? widget.onActivate : null,
                onHighlightChanged: (value) {
                  if (mounted && _pressed != value) {
                    setState(() => _pressed = value);
                  }
                },
                customBorder: rowShape,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashColor: colors.primary.withValues(alpha: 0.12),
                child: Padding(
                  padding:
                      widget.padding ??
                      EdgeInsets.symmetric(
                        horizontal: widget.compact ? 12 : 16,
                        vertical: widget.compact ? 8 : 12,
                      ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: contentOpacity,
                        child: M3LeadingSlot(child: widget.leading),
                      ),
                      SizedBox(width: widget.compact ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: widget.compact ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: foreground,
                                          fontWeight: widget.selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                  ),
                                ),
                                if (widget.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Opacity(
                                    opacity: contentOpacity,
                                    child: widget.badge!,
                                  ),
                                ],
                              ],
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 3),
                              Opacity(
                                opacity: contentOpacity,
                                child: widget.subtitle!,
                              ),
                            ],
                            if (widget.metadata != null) ...[
                              const SizedBox(height: 3),
                              Opacity(
                                opacity: contentOpacity,
                                child: widget.metadata!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 12),
                        Opacity(
                          opacity: contentOpacity,
                          child: widget.trailing!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedContainer(
      duration: AppMotion.of(context).state,
      curve: AppMotion.of(context).standardCurve,
      constraints: BoxConstraints(minHeight: widget.compact ? 56 : 72),
      child: content,
    );
  }
}
