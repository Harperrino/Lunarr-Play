import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Desktop-friendly scroll — mouse drag on timeline headers and scrollbars.
class EpgScrollBehavior extends MaterialScrollBehavior {
  const EpgScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
