import 'package:flutter/material.dart';

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.live,
    required this.onLive,
    required this.liveContainer,
    required this.onLiveContainer,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.focus,
  });

  static const dark = AppStatusColors(
    live: Color(0xFFFF667D),
    onLive: Color(0xFF41000D),
    liveContainer: Color(0xFF641526),
    onLiveContainer: Color(0xFFFFD9DE),
    success: Color(0xFF73DB91),
    successContainer: Color(0xFF0D4B28),
    onSuccessContainer: Color(0xFFA6F5B6),
    warning: Color(0xFFF2C66D),
    warningContainer: Color(0xFF503B00),
    onWarningContainer: Color(0xFFFFE39A),
    info: Color(0xFF82D0FF),
    infoContainer: Color(0xFF00364B),
    onInfoContainer: Color(0xFFC3E8FF),
    focus: Color(0xFFB6FFF0),
  );

  final Color live;
  final Color onLive;
  final Color liveContainer;
  final Color onLiveContainer;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color focus;

  @override
  AppStatusColors copyWith({
    Color? live,
    Color? onLive,
    Color? liveContainer,
    Color? onLiveContainer,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? focus,
  }) => AppStatusColors(
    live: live ?? this.live,
    onLive: onLive ?? this.onLive,
    liveContainer: liveContainer ?? this.liveContainer,
    onLiveContainer: onLiveContainer ?? this.onLiveContainer,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
    onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    focus: focus ?? this.focus,
  );

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      live: Color.lerp(live, other.live, t)!,
      onLive: Color.lerp(onLive, other.onLive, t)!,
      liveContainer: Color.lerp(liveContainer, other.liveContainer, t)!,
      onLiveContainer: Color.lerp(onLiveContainer, other.onLiveContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}
