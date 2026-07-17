import 'dart:async';

import 'package:flutter/material.dart';

/// Numeric stepper with tap (+/-1) and long-press repeat (faster increments).
class StepperControl extends StatefulWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix,
    this.longPressStep = 5,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? suffix;
  final int longPressStep;

  @override
  State<StepperControl> createState() => _StepperControlState();
}

class _StepperControlState extends State<StepperControl> {
  Timer? _repeatTimer;
  int _repeatTicks = 0;

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatTicks = 0;
  }

  void _applyDelta(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next != widget.value) widget.onChanged(next);
  }

  void _startRepeat(int delta) {
    _stopRepeat();
    _applyDelta(delta);
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _repeatTicks++;
      final step = _repeatTicks > 8 ? widget.longPressStep : 1;
      _applyDelta(delta * step);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          semanticLabel: 'Decrease value',
          enabled: widget.value > widget.min,
          onTap: () => _applyDelta(-1),
          onLongPressStart: () => _startRepeat(-1),
          onLongPressEnd: _stopRepeat,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            widget.suffix != null
                ? '${widget.value}${widget.suffix}'
                : '${widget.value}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          semanticLabel: 'Increase value',
          enabled: widget.value < widget.max,
          onTap: () => _applyDelta(1),
          onLongPressStart: () => _startRepeat(1),
          onLongPressEnd: _stopRepeat,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        onLongPressStart: enabled ? (_) => onLongPressStart() : null,
        onLongPressEnd: enabled ? (_) => onLongPressEnd() : null,
        onLongPressCancel: onLongPressEnd,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: enabled ? onTap : null,
          canRequestFocus: enabled,
          borderRadius: BorderRadius.circular(8),
          hoverColor: colorScheme.primaryContainer,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: enabled
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Icon(
              icon,
              size: 14,
              color: enabled
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
