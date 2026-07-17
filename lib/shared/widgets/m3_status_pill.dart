import 'package:flutter/material.dart';

/// Compact, provider-free status badge for settings, diagnostics and lists.
class M3StatusPill extends StatelessWidget {
  const M3StatusPill({
    super.key,
    required this.label,
    required this.accent,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  final String label;
  final Color accent;
  final Color? foreground;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = foreground ?? colors.onSurface;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: StadiumBorder(
              side: BorderSide(color: accent.withValues(alpha: 0.28)),
            ),
          ),
          child: Padding(
            padding: padding,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
