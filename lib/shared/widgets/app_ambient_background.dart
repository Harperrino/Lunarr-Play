import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';

/// Provider-free animated background for the complete application window.
class AppAmbientBackground extends StatefulWidget {
  const AppAmbientBackground({
    super.key,
    required this.preferences,
    this.animationEnabled = true,
  });

  final PlaybackPreferences preferences;

  /// Allows the app shell to suspend animation while an opaque fullscreen
  /// player covers the complete window without changing the stored setting.
  final bool animationEnabled;

  @override
  State<AppAmbientBackground> createState() => _AppAmbientBackgroundState();
}

class _AppAmbientBackgroundState extends State<AppAmbientBackground>
    with WidgetsBindingObserver {
  static const _fixedPhase = 0.18;

  final ValueNotifier<double> _phase = ValueNotifier<double>(_fixedPhase);
  Timer? _timer;
  late AppLifecycleState _lifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronizeTimer();
  }

  @override
  void didUpdateWidget(covariant AppAmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.ambientBackgroundEnabled !=
            widget.preferences.ambientBackgroundEnabled ||
        oldWidget.preferences.ambientMotion !=
            widget.preferences.ambientMotion ||
        oldWidget.animationEnabled != widget.animationEnabled) {
      _synchronizeTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (mounted) _synchronizeTimer();
  }

  bool get _shouldAnimate =>
      widget.animationEnabled &&
      widget.preferences.ambientBackgroundEnabled &&
      _lifecycleState == AppLifecycleState.resumed &&
      TickerMode.valuesOf(context).enabled &&
      !MediaQuery.disableAnimationsOf(context);

  void _synchronizeTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_shouldAnimate) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _phase.value = _fixedPhase;
      }
      return;
    }

    final interval = appAmbientFrameInterval(widget.preferences.ambientMotion);
    final cycle = switch (widget.preferences.ambientMotion) {
      PlayerAmbientMotion.slow => const Duration(seconds: 28),
      PlayerAmbientMotion.normal => const Duration(seconds: 18),
      PlayerAmbientMotion.fast => const Duration(seconds: 11),
    };
    final step = interval.inMicroseconds / cycle.inMicroseconds;
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      _phase.value = (_phase.value + step) % 1;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = widget.preferences;
    if (!preferences.ambientBackgroundEnabled) {
      return ColoredBox(
        key: const ValueKey('app-ambient-background-disabled'),
        color: Theme.of(context).colorScheme.surfaceDim,
      );
    }

    final highContrast = MediaQuery.highContrastOf(context);
    final intensity = highContrast
        ? math.min(preferences.ambientIntensity, 0.32)
        : preferences.ambientIntensity;
    final hues = appAmbientHues(preferences);
    return ColoredBox(
      key: const ValueKey('app-ambient-background'),
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (!size.width.isFinite ||
              !size.height.isFinite ||
              size.isEmpty ||
              intensity <= 0) {
            return const SizedBox.expand();
          }
          final shortest = math.min(size.width, size.height);
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              _cloud(
                index: 0,
                size: size,
                shortest: shortest,
                center: const Offset(0.18, 0.30),
                radiusFactor: 0.88,
                hue: hues.$1,
                alpha: 0.62,
                intensity: intensity,
                offsetForPhase: (phase) {
                  final angle = phase * math.pi * 2;
                  return Offset(
                    math.sin(angle) * size.width * 0.08,
                    math.cos(angle * 0.8) * size.height * 0.12,
                  );
                },
              ),
              _cloud(
                index: 1,
                size: size,
                shortest: shortest,
                center: const Offset(0.78, 0.68),
                radiusFactor: 0.82,
                hue: hues.$2,
                alpha: 0.58,
                intensity: intensity,
                offsetForPhase: (phase) {
                  final angle = phase * math.pi * 2;
                  return Offset(
                    math.cos(angle * 0.73) * size.width * 0.10,
                    math.sin(angle * 0.9) * size.height * 0.13,
                  );
                },
              ),
              _cloud(
                index: 2,
                size: size,
                shortest: shortest,
                center: const Offset(0.54, 0.22),
                radiusFactor: 0.56,
                hue: (hues.$1 + hues.$2) / 2,
                alpha: 0.38,
                intensity: intensity,
                offsetForPhase: (phase) {
                  final angle = phase * math.pi * 2;
                  return Offset(
                    math.sin(angle * 0.51) * size.width * 0.14,
                    math.cos(angle * 0.61) * size.height * 0.09,
                  );
                },
              ),
              _cloud(
                index: 3,
                size: size,
                shortest: shortest,
                center: const Offset(0.42, 0.86),
                radiusFactor: 0.60,
                hue: hues.$1,
                alpha: 0.28,
                intensity: intensity,
                offsetForPhase: (phase) {
                  final angle = phase * math.pi * 2;
                  return Offset(
                    math.cos(angle * 0.43) * size.width * 0.12,
                    math.sin(angle * 0.67) * size.height * 0.08,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cloud({
    required int index,
    required Size size,
    required double shortest,
    required Offset center,
    required double radiusFactor,
    required double hue,
    required double alpha,
    required double intensity,
    required Offset Function(double phase) offsetForPhase,
  }) {
    final radius = shortest * radiusFactor;
    return Positioned(
      left: size.width * center.dx - radius,
      top: size.height * center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: _MovingAmbientCloud(
        phase: _phase,
        offsetForPhase: offsetForPhase,
        child: RepaintBoundary(
          child: CustomPaint(
            key: ValueKey('app-ambient-cloud-$index'),
            painter: AppAmbientCloudPainter(
              hue: hue,
              intensity: intensity,
              alpha: alpha,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _MovingAmbientCloud extends StatelessWidget {
  const _MovingAmbientCloud({
    required this.phase,
    required this.offsetForPhase,
    required this.child,
  });

  final ValueListenable<double> phase;
  final Offset Function(double phase) offsetForPhase;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: phase,
    child: child,
    builder: (context, value, child) =>
        Transform.translate(offset: offsetForPhase(value), child: child),
  );
}

Duration appAmbientFrameInterval(PlayerAmbientMotion motion) =>
    switch (motion) {
      PlayerAmbientMotion.slow => const Duration(milliseconds: 84),
      PlayerAmbientMotion.normal => const Duration(milliseconds: 56),
      PlayerAmbientMotion.fast => const Duration(milliseconds: 42),
    };

(double, double) appAmbientHues(PlaybackPreferences preferences) =>
    switch (preferences.ambientPreset) {
      PlayerAmbientPreset.lunarr => (215, 285),
      PlayerAmbientPreset.aurora => (165, 270),
      PlayerAmbientPreset.ember => (12, 42),
      PlayerAmbientPreset.custom => (
        preferences.ambientCustomHueA,
        preferences.ambientCustomHueB,
      ),
    };

class AppAmbientCloudPainter extends CustomPainter {
  const AppAmbientCloudPainter({
    required this.hue,
    required this.intensity,
    required this.alpha,
  });

  final double hue;
  final double intensity;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || intensity <= 0 || alpha <= 0) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final color = HSVColor.fromAHSV(1, hue, 0.78, 0.95).toColor();
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: intensity * alpha),
            color.withValues(alpha: intensity * alpha * 0.28),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.46, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant AppAmbientCloudPainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.intensity != intensity ||
      oldDelegate.alpha != alpha;
}
