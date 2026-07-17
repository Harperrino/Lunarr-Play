import 'package:flutter/material.dart';

class NeuralBackground extends StatefulWidget {
  final Widget child;

  const NeuralBackground({super.key, required this.child});

  @override
  State<NeuralBackground> createState() => _NeuralBackgroundState();
}

class _NeuralBackgroundState extends State<NeuralBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) return;

    _animationsDisabled = animationsDisabled;
    if (animationsDisabled) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceDim,
      body: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: colors.surfaceDim)),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final ambient = Color.lerp(
                  colors.surfaceContainerLowest,
                  colors.surfaceContainerLow,
                  _controller.value * 0.16,
                )!;
                return IgnorePointer(
                  child: ColoredBox(color: ambient.withValues(alpha: 0.32)),
                );
              },
            ),
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}
