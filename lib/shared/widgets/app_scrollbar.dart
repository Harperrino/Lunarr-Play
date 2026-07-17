import 'dart:async';

import 'package:flutter/material.dart';

/// Auto-hiding tonal scrollbar for desktop surfaces.
class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    super.key,
    required this.controller,
    required this.child,
    required this.axis,
    this.padding = EdgeInsets.zero,
    this.thickness = 7,
    this.radius = 999,
  });

  final ScrollController controller;
  final Widget child;
  final Axis axis;
  final EdgeInsetsGeometry padding;
  final double thickness;
  final double radius;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _showTemporarily() {
    if (!mounted) return;
    setState(() => _visible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  Widget _wrapChild(Widget child) {
    if (widget.padding == EdgeInsets.zero) return child;
    return Padding(padding: widget.padding, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final scrollbar = Scrollbar(
      controller: widget.controller,
      thumbVisibility: _visible,
      trackVisibility: false,
      interactive: true,
      radius: Radius.circular(widget.radius),
      thickness: _visible ? widget.thickness : 0,
      notificationPredicate: (notification) =>
          notification.metrics.axis == widget.axis,
      child: _wrapChild(widget.child),
    );

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == widget.axis) {
            _showTemporarily();
          }
          return false;
        },
        child: MouseRegion(
          onEnter: (_) => _showTemporarily(),
          onHover: (_) => _showTemporarily(),
          onExit: (_) {
            _hideTimer?.cancel();
            _hideTimer = Timer(const Duration(milliseconds: 220), () {
              if (mounted) setState(() => _visible = false);
            });
          },
          child: scrollbar,
        ),
      ),
    );
  }
}
