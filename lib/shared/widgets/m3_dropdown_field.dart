import 'package:flutter/material.dart';

import '../theme/app_status_colors.dart';

/// Compact Material 3 dropdown field with the app's shared input contract.
class M3DropdownField<T> extends StatelessWidget {
  const M3DropdownField({
    super.key,
    required this.value,
    required this.entries,
    required this.onSelected,
    this.compact = false,
    this.width,
  });

  final T value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onSelected;
  final bool compact;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final focusColor =
        theme.extension<AppStatusColors>()?.focus ?? colors.primary;
    final radius = BorderRadius.circular(12);
    final contentPadding = EdgeInsets.symmetric(
      horizontal: compact ? 10 : 12,
      vertical: compact ? 6 : 8,
    );
    final inputTheme = InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: focusColor, width: 2),
      ),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
    final baseWidth = compact ? 136.0 : 160.0;
    final effectiveWidth = width ?? baseWidth + 52 * (textScale - 1);

    return DropdownMenu<T>(
      width: effectiveWidth,
      initialSelection: value,
      dropdownMenuEntries: entries,
      onSelected: onSelected,
      enableFilter: false,
      enableSearch: false,
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontSize: compact ? 11 : 12,
        color: colors.onSurface,
      ),
      inputDecorationTheme: inputTheme,
      trailingIcon: Icon(
        Icons.expand_more_rounded,
        size: compact ? 16 : 18,
        color: colors.onSurfaceVariant,
      ),
      selectedTrailingIcon: Icon(
        Icons.expand_less_rounded,
        size: compact ? 16 : 18,
        color: colors.onSurfaceVariant,
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
