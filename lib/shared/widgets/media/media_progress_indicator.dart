import 'package:flutter/material.dart';

import '../../theme/app_shapes.dart';

/// A semantic, determinate progress treatment for resume position.
class MediaProgressIndicator extends StatelessWidget {
  const MediaProgressIndicator({
    super.key,
    required this.progress,
    this.semanticLabel = 'Watch progress',
  });

  /// Resume progress. Values outside 0..1 are safely clamped for display.
  final double progress;

  final String semanticLabel;

  double get _value => progress.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final percentage = (_value * 100).round();

    return Semantics(
      label: semanticLabel,
      value: '$percentage%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(shapes.full),
          child: LinearProgressIndicator(
            value: _value,
            minHeight: 4,
            color: colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
