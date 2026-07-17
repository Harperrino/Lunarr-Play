import 'package:flutter/material.dart';

@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    this.state = const Duration(milliseconds: 120),
    this.content = const Duration(milliseconds: 180),
    this.rail = const Duration(milliseconds: 260),
    this.reduced = Duration.zero,
    this.standardCurve = Curves.easeOutCubic,
    this.emphasizedCurve = Curves.easeInOutCubic,
  });

  static const standard = AppMotion();

  /// Resolves the themed motion policy for [context].
  ///
  /// Platform accessibility settings take precedence over the theme: when
  /// animations are disabled, every duration falls back to [reduced]. Curves
  /// remain available for consumers that need a stable value even though the
  /// resulting duration is zero.
  static AppMotion of(BuildContext context) {
    final motion =
        Theme.of(context).extension<AppMotion>() ?? AppMotion.standard;
    if (!MediaQuery.disableAnimationsOf(context)) return motion;
    return motion.copyWith(
      state: motion.reduced,
      content: motion.reduced,
      rail: motion.reduced,
    );
  }

  final Duration state;
  final Duration content;
  final Duration rail;
  final Duration reduced;
  final Curve standardCurve;
  final Curve emphasizedCurve;

  @override
  AppMotion copyWith({
    Duration? state,
    Duration? content,
    Duration? rail,
    Duration? reduced,
    Curve? standardCurve,
    Curve? emphasizedCurve,
  }) => AppMotion(
    state: state ?? this.state,
    content: content ?? this.content,
    rail: rail ?? this.rail,
    reduced: reduced ?? this.reduced,
    standardCurve: standardCurve ?? this.standardCurve,
    emphasizedCurve: emphasizedCurve ?? this.emphasizedCurve,
  );

  @override
  AppMotion lerp(covariant AppMotion? other, double t) {
    if (other == null) return this;
    Duration duration(Duration a, Duration b) => Duration(
      microseconds:
          (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
              .round(),
    );
    return AppMotion(
      state: duration(state, other.state),
      content: duration(content, other.content),
      rail: duration(rail, other.rail),
      reduced: duration(reduced, other.reduced),
      standardCurve: t < 0.5 ? standardCurve : other.standardCurve,
      emphasizedCurve: t < 0.5 ? emphasizedCurve : other.emphasizedCurve,
    );
  }
}

/// Convenience resolver for widgets that already have a [BuildContext].
extension AppMotionContext on BuildContext {
  AppMotion get appMotion => AppMotion.of(this);
}
