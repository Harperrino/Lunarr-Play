import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Size tokens for the shared Material 3 Expressive slider.
enum M3ExpressiveSliderSize { xs, s, m, l, xl }

/// A provider-free, presentational Material 3 Expressive slider.
///
/// The component deliberately owns its pointer, keyboard, focus, hover, and
/// semantics behavior so consumers do not need to place a transparent
/// framework control over a custom-painted track. The value remains owned by
/// the consumer.
class M3ExpressiveSlider extends StatefulWidget {
  const M3ExpressiveSlider({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.size = M3ExpressiveSliderSize.s,
    this.bufferedValue,
    this.semanticFormatter,
    this.enabled = true,
  }) : assert(max > min);

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final M3ExpressiveSliderSize size;
  final double? bufferedValue;
  final String Function(double value)? semanticFormatter;
  final bool enabled;

  @override
  State<M3ExpressiveSlider> createState() => _M3ExpressiveSliderState();
}

class _M3ExpressiveSliderState extends State<M3ExpressiveSlider> {
  late final FocusNode _focusNode;
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;
  bool _interactionActive = false;
  double? _interactionValue;

  _M3ExpressiveSliderTokens get _tokens =>
      _M3ExpressiveSliderTokens.forSize(widget.size);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'M3ExpressiveSlider');
  }

  @override
  void didUpdateWidget(covariant M3ExpressiveSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactionActive) {
      _interactionValue = null;
    }
    if (!widget.enabled) {
      _isHovered = false;
      _isPressed = false;
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _clamp(double value) => value.clamp(widget.min, widget.max).toDouble();

  double get _displayValue => _clamp(_interactionValue ?? widget.value);

  double get _keyboardStep =>
      math.max((widget.max - widget.min) / 100, double.minPositive);

  double _stepValue(double value, {required bool increase}) =>
      _clamp(value + (increase ? _keyboardStep : -_keyboardStep));

  String _formatValue(double value) {
    final formatter = widget.semanticFormatter;
    if (formatter != null) return formatter(value);
    return value.toStringAsFixed(2);
  }

  void _setHovered(bool value) {
    if (!mounted || _isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _setFocused(bool value) {
    if (!mounted || _isFocused == value) return;
    setState(() => _isFocused = value);
  }

  void _beginInteraction() {
    if (!widget.enabled || _interactionActive) return;

    final startValue = _displayValue;
    _interactionActive = true;
    _interactionValue = startValue;
    _isPressed = true;
    _focusNode.requestFocus();
    setState(() {});
    widget.onChangeStart?.call(startValue);
  }

  void _beginPointerInteraction(Offset localPosition) {
    _beginInteraction();
    _updateFromLocalPosition(localPosition.dx);
  }

  void _updateFromLocalPosition(double localX) {
    if (!widget.enabled || !_interactionActive) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || renderObject.size.width <= 0) return;

    final trackInset = _tokens.activeHandleWidth / 2;
    final trackWidth = math.max(renderObject.size.width - trackInset * 2, 1.0);
    final fraction = ((localX - trackInset) / trackWidth).clamp(0.0, 1.0);
    _updateValue(widget.min + (widget.max - widget.min) * fraction);
  }

  void _updateValue(double value) {
    if (!widget.enabled || !_interactionActive) return;

    final nextValue = _clamp(value);
    final currentValue = _displayValue;
    if ((nextValue - currentValue).abs() < 0.0000001) return;

    _interactionValue = nextValue;
    setState(() {});
    widget.onChanged(nextValue);
  }

  void _endInteraction() {
    if (!_interactionActive) return;

    final endValue = _displayValue;
    _interactionActive = false;
    _isPressed = false;
    _interactionValue = null;
    setState(() {});
    widget.onChangeEnd?.call(endValue);
  }

  void _adjustByKeyboard({required bool increase}) {
    if (!widget.enabled) return;
    _beginInteraction();
    _updateValue(_stepValue(_displayValue, increase: increase));
    _endInteraction();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _adjustByKeyboard(increase: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _adjustByKeyboard(increase: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _beginInteraction();
      _updateValue(widget.min);
      _endInteraction();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _beginInteraction();
      _updateValue(widget.max);
      _endInteraction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = _displayValue;
    final tokens = _tokens;
    final inactiveColor = widget.enabled
        ? colors.surfaceContainerHighest
        : colors.onSurface.withValues(alpha: 0.12);
    final activeColor = widget.enabled
        ? colors.primary
        : colors.onSurface.withValues(alpha: 0.38);
    final bufferedColor = widget.enabled
        ? colors.secondaryContainer
        : colors.onSurface.withValues(alpha: 0.16);
    final handleColor = widget.enabled
        ? colors.primary
        : colors.onSurface.withValues(alpha: 0.38);
    final stateLayerColor = colors.primary.withValues(
      alpha: _isPressed ? 0.16 : (_isHovered || _isFocused ? 0.12 : 0.0),
    );

    return Semantics(
      container: true,
      slider: true,
      enabled: widget.enabled,
      focusable: widget.enabled,
      value: _formatValue(value),
      increasedValue: _formatValue(_stepValue(value, increase: true)),
      decreasedValue: _formatValue(_stepValue(value, increase: false)),
      onIncrease: widget.enabled
          ? () => _adjustByKeyboard(increase: true)
          : null,
      onDecrease: widget.enabled
          ? () => _adjustByKeyboard(increase: false)
          : null,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: widget.enabled,
        onFocusChange: _setFocused,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          onEnter: (_) => _setHovered(widget.enabled),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled
                ? (details) => _beginPointerInteraction(details.localPosition)
                : null,
            onTapUp: widget.enabled ? (_) => _endInteraction() : null,
            onTapCancel: widget.enabled ? _endInteraction : null,
            onPanStart: widget.enabled
                ? (details) => _beginPointerInteraction(details.localPosition)
                : null,
            onPanUpdate: widget.enabled
                ? (details) =>
                      _updateFromLocalPosition(details.localPosition.dx)
                : null,
            onPanEnd: widget.enabled ? (_) => _endInteraction() : null,
            onPanCancel: widget.enabled ? _endInteraction : null,
            child: SizedBox(
              height: tokens.hitHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _M3ExpressiveSliderPainter(
                  value: value,
                  min: widget.min,
                  max: widget.max,
                  bufferedValue: widget.bufferedValue,
                  tokens: tokens,
                  enabled: widget.enabled,
                  isHovered: _isHovered,
                  isFocused: _isFocused,
                  isPressed: _isPressed,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  bufferedColor: bufferedColor,
                  handleColor: handleColor,
                  stateLayerColor: stateLayerColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3ExpressiveSliderTokens {
  const _M3ExpressiveSliderTokens({
    required this.hitHeight,
    required this.trackHeight,
    required this.idleHandleWidth,
    required this.activeHandleWidth,
    required this.idleHandleHeight,
    required this.activeHandleHeight,
  });

  final double hitHeight;
  final double trackHeight;
  final double idleHandleWidth;
  final double activeHandleWidth;
  final double idleHandleHeight;
  final double activeHandleHeight;

  static _M3ExpressiveSliderTokens forSize(M3ExpressiveSliderSize size) {
    return switch (size) {
      M3ExpressiveSliderSize.xs => const _M3ExpressiveSliderTokens(
        hitHeight: 28,
        trackHeight: 4,
        idleHandleWidth: 5,
        activeHandleWidth: 9,
        idleHandleHeight: 16,
        activeHandleHeight: 22,
      ),
      M3ExpressiveSliderSize.s => const _M3ExpressiveSliderTokens(
        hitHeight: 36,
        trackHeight: 6,
        idleHandleWidth: 6,
        activeHandleWidth: 11,
        idleHandleHeight: 20,
        activeHandleHeight: 26,
      ),
      M3ExpressiveSliderSize.m => const _M3ExpressiveSliderTokens(
        hitHeight: 44,
        trackHeight: 8,
        idleHandleWidth: 8,
        activeHandleWidth: 13,
        idleHandleHeight: 24,
        activeHandleHeight: 30,
      ),
      M3ExpressiveSliderSize.l => const _M3ExpressiveSliderTokens(
        hitHeight: 52,
        trackHeight: 10,
        idleHandleWidth: 10,
        activeHandleWidth: 15,
        idleHandleHeight: 28,
        activeHandleHeight: 34,
      ),
      M3ExpressiveSliderSize.xl => const _M3ExpressiveSliderTokens(
        hitHeight: 60,
        trackHeight: 12,
        idleHandleWidth: 12,
        activeHandleWidth: 17,
        idleHandleHeight: 32,
        activeHandleHeight: 38,
      ),
    };
  }
}

class _M3ExpressiveSliderPainter extends CustomPainter {
  const _M3ExpressiveSliderPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.bufferedValue,
    required this.tokens,
    required this.enabled,
    required this.isHovered,
    required this.isFocused,
    required this.isPressed,
    required this.activeColor,
    required this.inactiveColor,
    required this.bufferedColor,
    required this.handleColor,
    required this.stateLayerColor,
  });

  final double value;
  final double min;
  final double max;
  final double? bufferedValue;
  final _M3ExpressiveSliderTokens tokens;
  final bool enabled;
  final bool isHovered;
  final bool isFocused;
  final bool isPressed;
  final Color activeColor;
  final Color inactiveColor;
  final Color bufferedColor;
  final Color handleColor;
  final Color stateLayerColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final handleWidth = isPressed || isFocused
        ? tokens.activeHandleWidth
        : tokens.idleHandleWidth;
    final handleHeight = isPressed || isFocused
        ? tokens.activeHandleHeight
        : tokens.idleHandleHeight;
    final trackInset = tokens.activeHandleWidth / 2;
    final trackLeft = trackInset;
    final trackRight = math.max(size.width - trackInset, trackLeft);
    final trackWidth = trackRight - trackLeft;
    final handleCenter = trackLeft + trackWidth * fraction;
    final trackTop = (size.height - tokens.trackHeight) / 2;
    final trackBottom = trackTop + tokens.trackHeight;
    final gap = math.max(3.0, handleWidth / 2 + 2);
    final activeEnd = (handleCenter - handleWidth / 2 - gap).clamp(
      trackLeft,
      trackRight,
    );
    final inactiveStart = (handleCenter + handleWidth / 2 + gap).clamp(
      trackLeft,
      trackRight,
    );

    _drawSegment(
      canvas,
      start: trackLeft,
      end: activeEnd,
      top: trackTop,
      bottom: trackBottom,
      color: activeColor,
    );
    _drawSegment(
      canvas,
      start: inactiveStart,
      end: trackRight,
      top: trackTop,
      bottom: trackBottom,
      color: inactiveColor,
    );

    final buffered = bufferedValue;
    if (buffered != null && buffered > value && inactiveStart < trackRight) {
      final bufferedFraction = ((buffered - min) / (max - min)).clamp(0.0, 1.0);
      final bufferedEnd = (trackLeft + trackWidth * bufferedFraction).clamp(
        inactiveStart,
        trackRight,
      );
      _drawSegment(
        canvas,
        start: inactiveStart,
        end: bufferedEnd,
        top: trackTop,
        bottom: trackBottom,
        color: bufferedColor,
      );
    }

    final stateLayerVisible = isHovered || isFocused || isPressed;
    if (enabled && stateLayerVisible && stateLayerColor.a > 0) {
      final stateWidth = handleWidth + 18;
      final stateHeight = math.min(size.height, handleHeight + 14);
      final stateRect = Rect.fromCenter(
        center: Offset(handleCenter, size.height / 2),
        width: stateWidth,
        height: stateHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          stateRect,
          Radius.circular(math.min(stateWidth, stateHeight) / 2),
        ),
        Paint()..color = stateLayerColor,
      );
    }

    final handleRect = Rect.fromCenter(
      center: Offset(handleCenter, size.height / 2),
      width: handleWidth,
      height: handleHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        handleRect,
        Radius.circular(math.min(handleWidth, handleHeight) / 2),
      ),
      Paint()..color = handleColor,
    );
  }

  void _drawSegment(
    Canvas canvas, {
    required double start,
    required double end,
    required double top,
    required double bottom,
    required Color color,
  }) {
    if (end <= start) return;
    final rect = Rect.fromLTRB(start, top, end, bottom);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(tokens.trackHeight / 2)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _M3ExpressiveSliderPainter oldDelegate) {
    return value != oldDelegate.value ||
        min != oldDelegate.min ||
        max != oldDelegate.max ||
        bufferedValue != oldDelegate.bufferedValue ||
        tokens != oldDelegate.tokens ||
        enabled != oldDelegate.enabled ||
        isHovered != oldDelegate.isHovered ||
        isFocused != oldDelegate.isFocused ||
        isPressed != oldDelegate.isPressed ||
        activeColor != oldDelegate.activeColor ||
        inactiveColor != oldDelegate.inactiveColor ||
        bufferedColor != oldDelegate.bufferedColor ||
        handleColor != oldDelegate.handleColor ||
        stateLayerColor != oldDelegate.stateLayerColor;
  }
}
