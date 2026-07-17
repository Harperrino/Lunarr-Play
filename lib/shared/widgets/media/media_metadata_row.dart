import 'package:flutter/material.dart';

import '../../theme/app_shapes.dart';
import '../../theme/app_spacing.dart';

/// A compact title, metadata and badge treatment for media cards.
class MediaMetadataRow extends StatelessWidget {
  const MediaMetadataRow({
    super.key,
    required this.title,
    this.subtitle,
    this.badges = const <MediaMetadataBadge>[],
  });

  final String title;
  final String? subtitle;
  final List<MediaMetadataBadge> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? AppSpacing.standard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (badges.isNotEmpty) ...<Widget>[
              SizedBox(width: spacing.sm),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: spacing.xs,
                    runSpacing: spacing.xs,
                    children: badges,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
          SizedBox(height: spacing.xs),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A tonal, concise descriptor used by [MediaMetadataRow].
class MediaMetadataBadge extends StatelessWidget {
  const MediaMetadataBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spacing = theme.extension<AppSpacing>() ?? AppSpacing.standard;
    final shapes = theme.extension<AppShapes>() ?? AppShapes.standard;

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          decoration: ShapeDecoration(
            color: colors.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(shapes.full),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: colors.onSecondaryContainer),
                SizedBox(width: spacing.xs),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
