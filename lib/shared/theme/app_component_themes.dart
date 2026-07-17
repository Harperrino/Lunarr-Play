import 'package:flutter/material.dart';

import '../../core/services/live_composition_geometry.dart';
import 'app_elevation.dart';
import 'app_shapes.dart';
import 'app_status_colors.dart';

abstract final class AppComponentThemes {
  static ButtonStyle filledButton(AppStatusColors status) =>
      FilledButton.styleFrom(
        minimumSize: const Size(40, 40),
        shape: const StadiumBorder(),
      ).copyWith(side: _focusSide(status.focus));

  static ButtonStyle outlinedButton(
    ColorScheme colors,
    AppStatusColors status,
  ) => OutlinedButton.styleFrom(
    minimumSize: const Size(40, 40),
    shape: const StadiumBorder(),
    side: BorderSide(color: colors.outline),
  ).copyWith(side: _focusSide(status.focus, fallback: colors.outline));

  static ButtonStyle textButton(
    ColorScheme colors,
    AppStatusColors status,
    AppShapes shapes,
  ) =>
      TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        ),
        foregroundColor: colors.primary,
      ).copyWith(
        overlayColor: _stateOverlay(colors.primary),
        side: _focusSide(status.focus),
      );

  static ButtonStyle iconButton(
    ColorScheme colors,
    AppStatusColors status,
    AppShapes shapes,
  ) =>
      IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        ),
        foregroundColor: colors.onSurfaceVariant,
      ).copyWith(
        overlayColor: _stateOverlay(colors.onSurface),
        side: _focusSide(status.focus),
      );

  static ButtonStyle elevatedButton(
    ColorScheme colors,
    AppStatusColors status,
    AppShapes shapes,
  ) =>
      ElevatedButton.styleFrom(
        minimumSize: const Size(40, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        ),
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurface,
        elevation: AppElevation.level0,
      ).copyWith(
        overlayColor: _stateOverlay(colors.onSurface),
        side: _focusSide(status.focus),
      );

  static CardThemeData card(ColorScheme colors, AppShapes shapes) =>
      CardThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        // The global Card contract is the filled/outlined Level-0 variant.
        // Elevated interactive cards opt in through AppSurface's Level-1
        // elevation and the shared state resolver instead of adding a second
        // shadow to this outline.
        shadowColor: Colors.transparent,
        elevation: AppElevation.level0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.large),
          side: BorderSide(color: colors.outlineVariant),
        ),
      );

  static DialogThemeData dialog(ColorScheme colors, AppShapes shapes) =>
      DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.extraLarge),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      );

  static BottomSheetThemeData bottomSheet(
    ColorScheme colors,
    AppShapes shapes,
  ) => BottomSheetThemeData(
    backgroundColor: colors.surfaceContainerLow,
    modalBackgroundColor: colors.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    elevation: AppElevation.level3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(shapes.extraLarge),
      ),
    ),
    showDragHandle: true,
    dragHandleColor: colors.onSurfaceVariant,
  );

  static PopupMenuThemeData popupMenu(ColorScheme colors, AppShapes shapes) =>
      PopupMenuThemeData(
        color: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.large),
        ),
        textStyle: TextStyle(color: colors.onSurface),
      );

  static ListTileThemeData listTile(ColorScheme colors, AppShapes shapes) =>
      ListTileThemeData(
        dense: false,
        minTileHeight: 48,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        ),
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        selectedColor: colors.onPrimaryContainer,
        selectedTileColor: colors.primaryContainer,
      );

  static NavigationRailThemeData navigationRail(
    ColorScheme colors,
    AppShapes shapes,
  ) => NavigationRailThemeData(
    backgroundColor: colors.surface,
    indicatorColor: colors.secondaryContainer,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapes.large),
    ),
    selectedIconTheme: IconThemeData(color: colors.onSecondaryContainer),
    unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
    selectedLabelTextStyle: TextStyle(
      color: colors.onSurface,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
    minWidth: LiveCompositionMetrics.shellSidebarCollapsedWidth,
    minExtendedWidth: LiveCompositionMetrics.shellSidebarExpandedWidth,
    useIndicator: true,
  );

  static NavigationBarThemeData navigationBar(ColorScheme colors) =>
      NavigationBarThemeData(
        height: 80,
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? colors.onSurface
                : colors.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      );

  static TabBarThemeData tabBar(ColorScheme colors, AppShapes shapes) =>
      TabBarThemeData(
        labelColor: colors.onSurface,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        // The shelf owns the carrier edge; selection is communicated by the
        // indicator only, so a second divider would create a duplicate rule.
        dividerColor: Colors.transparent,
        overlayColor: _stateOverlay(colors.primary),
        splashFactory: InkSparkle.splashFactory,
        tabAlignment: TabAlignment.start,
      );

  static SwitchThemeData switchControl(
    ColorScheme colors,
    AppStatusColors status,
  ) => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.onSurface.withValues(alpha: 0.38);
      }
      return states.contains(WidgetState.selected)
          ? colors.onPrimary
          : colors.outline;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.onSurface.withValues(alpha: 0.12);
      }
      return states.contains(WidgetState.selected)
          ? colors.primary
          : colors.surfaceContainerHighest;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return status.focus;
      }
      if (states.contains(WidgetState.selected)) {
        return Colors.transparent;
      }
      return colors.outline;
    }),
  );

  static CheckboxThemeData checkbox(
    ColorScheme colors,
    AppStatusColors status,
    AppShapes shapes,
  ) => CheckboxThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapes.extraSmall),
    ),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.onSurface.withValues(alpha: 0.12);
      }
      return states.contains(WidgetState.selected)
          ? colors.primary
          : Colors.transparent;
    }),
    checkColor: WidgetStatePropertyAll(colors.onPrimary),
    side: WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: status.focus, width: 2);
      }
      return BorderSide(color: colors.outline, width: 2);
    }),
  );

  static RadioThemeData radio(ColorScheme colors, AppStatusColors status) =>
      RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.onSurface.withValues(alpha: 0.38);
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.onSurfaceVariant;
        }),
        overlayColor: _stateOverlay(colors.primary),
      );

  static ProgressIndicatorThemeData progress(ColorScheme colors) =>
      ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        circularTrackColor: colors.surfaceContainerHighest,
        refreshBackgroundColor: colors.surfaceContainerHigh,
      );

  static SnackBarThemeData snackBar(ColorScheme colors, AppShapes shapes) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.onInverseSurface),
        actionTextColor: colors.inversePrimary,
        elevation: AppElevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        ),
      );

  static DropdownMenuThemeData dropdownMenu(
    ColorScheme colors,
    AppStatusColors status,
    AppShapes shapes,
  ) => DropdownMenuThemeData(
    inputDecorationTheme: input(colors, status, shapes),
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.large),
        ),
      ),
    ),
  );

  static SegmentedButtonThemeData segmentedButton(
    ColorScheme colors,
    AppShapes shapes,
  ) => SegmentedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
        ),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.outline,
        );
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colors.secondaryContainer
            : Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colors.onSecondaryContainer
            : colors.onSurfaceVariant;
      }),
    ),
  );

  static InputDecorationTheme input(
    ColorScheme colors,
    AppStatusColors status,
    AppShapes shapes,
  ) => InputDecorationTheme(
    filled: true,
    fillColor: colors.surfaceContainerHigh,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(shapes.medium)),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(shapes.medium)),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(shapes.medium)),
      borderSide: BorderSide(color: status.focus, width: 2),
    ),
  );

  static TooltipThemeData tooltip(ColorScheme colors, AppShapes shapes) =>
      TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(shapes.small),
        ),
        textStyle: TextStyle(color: colors.onInverseSurface),
        waitDuration: const Duration(milliseconds: 500),
      );

  static ChipThemeData chip(ColorScheme colors, AppStatusColors status) =>
      ChipThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        selectedColor: colors.primaryContainer,
        disabledColor: colors.surfaceContainerLow,
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: status.focus, width: 2);
          }
          return BorderSide(color: colors.outlineVariant);
        }),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(color: colors.onSurface),
        secondaryLabelStyle: TextStyle(color: colors.onPrimaryContainer),
      );

  static WidgetStateProperty<BorderSide?> _focusSide(
    Color focus, {
    Color? fallback,
  }) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.focused)) {
      return BorderSide(color: focus, width: 2);
    }
    return fallback == null ? null : BorderSide(color: fallback);
  });

  static WidgetStateProperty<Color?> _stateOverlay(Color color) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return color.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.12);
        }
        return null;
      });
}
