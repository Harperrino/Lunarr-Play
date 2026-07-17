import 'package:flutter/material.dart';

import '../theme/app_elevation.dart';
import 'app_surface.dart';

/// Tonal carrier for a real Material [TabBar].
///
/// The shelf owns the surface and elevation; individual tabs only own their
/// selection indicator and never add a second contour or shadow.
class M3TabShelf extends StatelessWidget {
  const M3TabShelf({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.low,
      elevation: AppElevation.level1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: child,
    );
  }
}
