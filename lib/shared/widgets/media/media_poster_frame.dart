import 'package:flutter/material.dart';

import '../../theme/app_elevation.dart';
import '../../theme/app_shapes.dart';
import '../app_surface.dart';

/// An interactive, tonal 2:3 media-poster frame.
///
/// The caller owns image loading and supplies [poster], so this shared
/// presentation primitive has no network, cache, or feature dependency.
class MediaPosterFrame extends StatefulWidget {
  const MediaPosterFrame({
    super.key,
    required this.poster,
    required this.semanticLabel,
    this.onActivate,
    this.isSelected = false,
    this.focusNode,
    this.autofocus = false,
  });

  /// The 2:3 poster contents, usually an image or a local placeholder.
  final Widget poster;

  /// Concise, user-facing description announced as the button label.
  final String semanticLabel;

  /// Invoked by pointer tap or keyboard activation. A null value disables it.
  final VoidCallback? onActivate;

  /// Whether this poster is the active selection in its owning grid.
  final bool isSelected;

  /// Optional focus owner for keyboard navigation and restoration.
  final FocusNode? focusNode;

  /// Whether this poster should receive focus when it is first mounted.
  final bool autofocus;

  @override
  State<MediaPosterFrame> createState() => _MediaPosterFrameState();
}

class _MediaPosterFrameState extends State<MediaPosterFrame> {
  static const _posterInset = 2.0;

  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.onActivate != null;

  Set<WidgetState> get _states => <WidgetState>{
    if (!_enabled) WidgetState.disabled,
    if (widget.isSelected) WidgetState.selected,
    if (_hovered) WidgetState.hovered,
    if (_focused) WidgetState.focused,
    if (_pressed) WidgetState.pressed,
  };

  void _updateState({bool? hovered, bool? focused, bool? pressed}) {
    if (!mounted) return;
    setState(() {
      _hovered = hovered ?? _hovered;
      _focused = focused ?? _focused;
      _pressed = pressed ?? _pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shapes =
        Theme.of(context).extension<AppShapes>() ?? AppShapes.standard;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapes.large),
    );
    final posterBorderRadius = BorderRadius.circular(
      (shapes.large - _posterInset).clamp(0.0, double.infinity).toDouble(),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.isSelected,
      label: widget.semanticLabel,
      onTap: _enabled ? widget.onActivate : null,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: AppSurface(
          level: AppSurfaceLevel.low,
          elevation: AppElevation.level1,
          elevationBehavior: AppElevationBehavior.elevatedCard,
          shape: shape,
          states: _states,
          child: InkWell(
            excludeFromSemantics: true,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            canRequestFocus: _enabled,
            onTap: widget.onActivate,
            onHover: (value) => _updateState(hovered: value),
            onFocusChange: (value) => _updateState(focused: value),
            onHighlightChanged: (value) => _updateState(pressed: value),
            overlayColor: const WidgetStatePropertyAll<Color>(
              Colors.transparent,
            ),
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              key: const ValueKey('media-poster-frame-inset'),
              padding: const EdgeInsets.all(_posterInset),
              child: ClipRRect(
                borderRadius: posterBorderRadius,
                child: SizedBox.expand(child: widget.poster),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
