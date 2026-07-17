import 'dart:math' as math;

import 'package:flutter/material.dart';

class EpgScreenVerticalMetrics {
  const EpgScreenVerticalMetrics({
    required this.gap,
    required this.maximumToolbarHeight,
  });

  static const standardGap = 16.0;
  static const minimumBodyHeight = 96.0;
  static const minimumScrollableToolbarHeight = 48.0;

  final double gap;
  final double maximumToolbarHeight;

  static EpgScreenVerticalMetrics resolve(double availableHeight) {
    final safeHeight = math.max(0.0, availableHeight);
    final preferredHeight =
        minimumBodyHeight + minimumScrollableToolbarHeight + standardGap;
    final gap = safeHeight >= preferredHeight ? standardGap : 0.0;
    final remaining = math.max(0.0, safeHeight - gap);
    final reservedToolbarHeight = math.min(
      minimumScrollableToolbarHeight,
      remaining,
    );
    final reservedBodyHeight = math.min(
      minimumBodyHeight,
      math.max(0.0, remaining - reservedToolbarHeight),
    );
    return EpgScreenVerticalMetrics(
      gap: gap,
      maximumToolbarHeight: math.max(0.0, remaining - reservedBodyHeight),
    );
  }
}

/// Provider-free vertical composition for the EPG toolbar and responsive body.
class EpgScreenLayout extends StatelessWidget {
  const EpgScreenLayout({super.key, required this.toolbar, required this.body});

  final Widget toolbar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = EpgScreenVerticalMetrics.resolve(constraints.maxHeight);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: metrics.maximumToolbarHeight,
              ),
              child: SingleChildScrollView(
                key: const ValueKey('epg-toolbar-vertical-scroll'),
                child: toolbar,
              ),
            ),
            SizedBox(height: metrics.gap),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
