import 'package:flutter/material.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

/// Tonal desktop frame for the EPG timeline without changing its scroll model.
class EpgGridFrame extends StatelessWidget {
  const EpgGridFrame({super.key, required this.child});

  final Widget child;

  static EdgeInsets paddingForWidth(double width) =>
      EdgeInsets.all(width >= 1200 ? 16 : 12);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AppSurface(
        key: const ValueKey('epg-grid-surface'),
        level: AppSurfaceLevel.standard,
        padding: paddingForWidth(constraints.maxWidth),
        child: child,
      ),
    );
  }
}
