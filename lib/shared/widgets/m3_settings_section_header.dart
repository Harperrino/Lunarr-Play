import 'package:flutter/material.dart';

import '../theme/app_component_metrics.dart';
import 'm3_slots.dart';

/// Shared provider-free heading geometry for settings sections.
class M3SettingsSectionHeader extends StatelessWidget {
  const M3SettingsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.titleSuffix,
    this.trailing,
    this.compact = false,
    this.iconColor,
    this.iconBackgroundColor,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? titleSuffix;
  final Widget? trailing;
  final bool compact;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = iconColor ?? colors.primary;
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);

    Widget buildLeadingContent({required bool includeTrailing}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        M3LeadingSlot(
          icon: icon,
          foregroundColor: color,
          backgroundColor: iconBackgroundColor ?? colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 12 : 13),
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                  ),
                  if (titleSuffix != null) ...[
                    const SizedBox(width: 8),
                    titleSuffix!,
                  ],
                ],
              ),
              if (description != null && !compact) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (includeTrailing && trailing != null) ...[
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppComponentMetrics.slotHitTarget,
            ),
            child: trailing!,
          ),
        ],
      ],
    );

    if (trailing == null) return buildLeadingContent(includeTrailing: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackBreakpoint = 560 * textScale.clamp(1, 1.5);
        final stackTrailing =
            constraints.hasBoundedWidth &&
            constraints.maxWidth < stackBreakpoint;
        if (!stackTrailing) return buildLeadingContent(includeTrailing: true);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildLeadingContent(includeTrailing: false),
            SizedBox(height: compact ? 8 : 12),
            Align(alignment: Alignment.centerRight, child: trailing!),
          ],
        );
      },
    );
  }
}
