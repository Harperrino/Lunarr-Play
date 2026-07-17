import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import '../theme/app_motion.dart';
import '../theme/app_status_colors.dart';

/// Semantic state treatment shared by the Material surface primitives.
///
/// Consumers provide their interaction state so these presentation primitives
/// remain independent of gestures and business logic.
@immutable
class AppSurfaceStateStyle {
  const AppSurfaceStateStyle({
    required this.overlayColor,
    required this.contentOpacity,
    this.surfaceColor,
    this.focusColor,
  });

  final Color overlayColor;
  final double contentOpacity;
  final Color? surfaceColor;
  final Color? focusColor;

  bool get hasFocusOutline => focusColor != null;
}

/// Controls the decoration implementation used by the externally spaced
/// focus outline. Rounded navigation rows can use a box decoration so their
/// outline remains compatible with the shell's existing geometry contract;
/// normal surfaces keep the shape decoration used by the shared surface API.
enum AppFocusOutlineStyle { shape, box }

/// Applies the semantic state layer and an externally spaced focus outline.
class AppSurfaceStateLayer extends StatelessWidget {
  const AppSurfaceStateLayer({
    super.key,
    required this.child,
    required this.shape,
    required this.surfaceColor,
    this.states = const <WidgetState>{},
    this.elevation = AppElevation.level0,
    this.elevationBehavior = AppElevationBehavior.staticSurface,
    this.defaultForegroundColor,
    this.selectedForegroundColor,
    this.selectedSurfaceColor,
    this.disabledSurfaceColor,
    this.focusOutlineKey,
    this.focusOutlineStyle = AppFocusOutlineStyle.shape,
  });

  static const double focusOutlineWidth = 2;
  static const double focusOutlineGap = 2;

  final Widget child;
  final OutlinedBorder shape;
  final Color surfaceColor;
  final Set<WidgetState> states;
  final double elevation;
  final AppElevationBehavior elevationBehavior;
  final Color? defaultForegroundColor;
  final Color? selectedForegroundColor;
  final Color? selectedSurfaceColor;
  final Color? disabledSurfaceColor;
  final Key? focusOutlineKey;
  final AppFocusOutlineStyle focusOutlineStyle;

  /// Resolves semantic colors without requiring a widget test or BuildContext.
  static AppSurfaceStateStyle resolve(
    ColorScheme colorScheme,
    AppStatusColors? statusColors,
    Set<WidgetState> states, {
    Color? defaultForegroundColor,
    Color? selectedForegroundColor,
    Color? selectedSurfaceColor,
    Color? disabledSurfaceColor,
  }) {
    final isDisabled = states.contains(WidgetState.disabled);
    final isSelected = !isDisabled && states.contains(WidgetState.selected);
    final isPressed = !isDisabled && states.contains(WidgetState.pressed);
    final isHovered = !isDisabled && states.contains(WidgetState.hovered);
    final isFocused = !isDisabled && states.contains(WidgetState.focused);

    final foreground = isSelected
        ? selectedForegroundColor ?? colorScheme.onPrimaryContainer
        : defaultForegroundColor ?? colorScheme.onSurface;
    final overlayAlpha = isPressed
        ? 0.12
        : isHovered
        ? 0.08
        : isDisabled
        ? 0.12
        : 0.0;

    return AppSurfaceStateStyle(
      surfaceColor: isDisabled
          ? disabledSurfaceColor ?? colorScheme.surfaceContainerLow
          : isSelected
          ? selectedSurfaceColor ?? colorScheme.primaryContainer
          : null,
      overlayColor: foreground.withValues(alpha: overlayAlpha),
      contentOpacity: isDisabled ? 0.38 : 1,
      focusColor: isFocused
          ? (statusColors?.focus ?? colorScheme.primary)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = resolve(
      Theme.of(context).colorScheme,
      Theme.of(context).extension<AppStatusColors>(),
      states,
      defaultForegroundColor: defaultForegroundColor,
      selectedForegroundColor: selectedForegroundColor,
      selectedSurfaceColor: selectedSurfaceColor,
      disabledSurfaceColor: disabledSurfaceColor,
    );
    final borderlessShape = shape.copyWith(side: BorderSide.none);
    final layeredChild = DecoratedBox(
      decoration: ShapeDecoration(
        color: style.overlayColor,
        shape: borderlessShape,
      ),
      position: DecorationPosition.foreground,
      child: Opacity(opacity: style.contentOpacity, child: child),
    );
    final material = Material(
      color: style.surfaceColor ?? surfaceColor,
      elevation: AppElevation.resolveForStates(
        elevation,
        states,
        behavior: elevationBehavior,
      ),
      animationDuration: AppMotion.of(context).state,
      shadowColor: AppElevation.shadowColorFor(
        Theme.of(context).colorScheme,
        AppElevation.resolveForStates(
          elevation,
          states,
          behavior: elevationBehavior,
        ),
      ),
      surfaceTintColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: layeredChild,
    );

    // Keep the focus treatment outside the surface's layout bounds.  Padding
    // here would make every focused consumer larger (and would shrink a
    // bounded child), which causes grids and cards to jump when focus moves.
    // The non-positioned material establishes the Stack's exact size while
    // the decorative outline is allowed to paint into the surrounding space.
    final focusDecoration =
        style.hasFocusOutline &&
            focusOutlineStyle == AppFocusOutlineStyle.box &&
            shape is RoundedRectangleBorder
        ? BoxDecoration(
            borderRadius: (shape as RoundedRectangleBorder).borderRadius.add(
              const BorderRadius.all(
                Radius.circular(focusOutlineWidth + focusOutlineGap),
              ),
            ),
            border: Border.all(
              color: style.focusColor!,
              width: focusOutlineWidth,
            ),
          )
        : style.hasFocusOutline
        ? ShapeDecoration(
            shape: shape.copyWith(
              side: BorderSide(
                color: style.focusColor!,
                width: focusOutlineWidth,
              ),
            ),
          )
        : null;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        material,
        if (style.hasFocusOutline)
          Positioned(
            key: focusOutlineKey == null
                ? const ValueKey<String>('app-surface-focus-outline')
                : null,
            left: -(focusOutlineWidth + focusOutlineGap),
            top: -(focusOutlineWidth + focusOutlineGap),
            right: -(focusOutlineWidth + focusOutlineGap),
            bottom: -(focusOutlineWidth + focusOutlineGap),
            child: IgnorePointer(
              child: DecoratedBox(
                key: focusOutlineKey,
                decoration: focusDecoration!,
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}
