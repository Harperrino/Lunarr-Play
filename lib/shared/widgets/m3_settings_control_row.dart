import 'package:flutter/material.dart';

/// Provider-free label/control geometry for settings rows.
///
/// The control moves below the label when text scaling leaves too little
/// horizontal room. This keeps the control right-aligned without clipping the
/// label or relying on intrinsic layout passes.
class M3SettingsControlRow extends StatelessWidget {
  const M3SettingsControlRow({
    super.key,
    required this.label,
    required this.control,
    this.compact = false,
  });

  final String label;
  final Widget control;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
    final labelWidget = Text(
      label,
      style: TextStyle(
        fontSize: compact ? 11.5 : 12,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackBreakpoint = 360 + 160 * (textScale - 1);
        final stackControl =
            constraints.hasBoundedWidth &&
            constraints.maxWidth < stackBreakpoint;

        if (stackControl) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              SizedBox(height: compact ? 6 : 8),
              Align(alignment: Alignment.centerRight, child: control),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: labelWidget),
            SizedBox(width: compact ? 12 : 16),
            control,
          ],
        );
      },
    );
  }
}
