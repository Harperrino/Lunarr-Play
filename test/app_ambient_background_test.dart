import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/playback_preferences.dart';
import 'package:m3uxtream_player/shared/widgets/app_ambient_background.dart';

const _runAmbient4kPerf = bool.fromEnvironment('AMBIENT_4K_PERF');

Widget _host(
  PlaybackPreferences preferences, {
  bool highContrast = false,
  bool disableAnimations = true,
  bool tickerEnabled = true,
  bool animationEnabled = true,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: disableAnimations,
      highContrast: highContrast,
    ),
    child: TickerMode(
      enabled: tickerEnabled,
      child: SizedBox(
        width: 640,
        height: 360,
        child: AppAmbientBackground(
          preferences: preferences,
          animationEnabled: animationEnabled,
        ),
      ),
    ),
  ),
);

void main() {
  test('presets resolve deterministic hue pairs', () {
    expect(appAmbientHues(const PlaybackPreferences()), (215, 285));
    expect(
      appAmbientHues(
        const PlaybackPreferences(ambientPreset: PlayerAmbientPreset.aurora),
      ),
      (165, 270),
    );
    expect(
      appAmbientHues(
        const PlaybackPreferences(
          ambientPreset: PlayerAmbientPreset.custom,
          ambientCustomHueA: 101,
          ambientCustomHueB: 202,
        ),
      ),
      (101, 202),
    );
  });

  testWidgets('disabled mode uses the static semantic app surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const PlaybackPreferences(ambientBackgroundEnabled: false)),
    );
    final disabled = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('app-ambient-background-disabled')),
    );
    final context = tester.element(
      find.byKey(const ValueKey('app-ambient-background-disabled')),
    );
    expect(disabled.color, Theme.of(context).colorScheme.surfaceDim);
    expect(find.byKey(const ValueKey('app-ambient-cloud-0')), findsNothing);
  });

  testWidgets('reduced motion freezes and high contrast caps intensity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const PlaybackPreferences(ambientIntensity: 0.9),
        highContrast: true,
      ),
    );
    final paintFinder = find.byKey(const ValueKey('app-ambient-cloud-0'));
    final customPaint = tester.widget<CustomPaint>(paintFinder);
    final painter = customPaint.painter! as AppAmbientCloudPainter;
    expect(painter.intensity, 0.32);
    final transform = tester.widget<Transform>(
      find.ancestor(of: paintFinder, matching: find.byType(Transform)).first,
    );
    await tester.pump(const Duration(seconds: 1));
    final nextTransform = tester.widget<Transform>(
      find.ancestor(of: paintFinder, matching: find.byType(Transform)).first,
    );
    expect(nextTransform.transform, transform.transform);
  });

  testWidgets(
    'animation moves cached cloud layers without replacing painters',
    (tester) async {
      await tester.pumpWidget(
        _host(const PlaybackPreferences(), disableAnimations: false),
      );
      final paintFinder = find.byKey(const ValueKey('app-ambient-cloud-0'));
      final beforePaint = tester.widget<CustomPaint>(paintFinder);
      final beforeTransform = tester.widget<Transform>(
        find.ancestor(of: paintFinder, matching: find.byType(Transform)).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      final afterPaint = tester.widget<CustomPaint>(paintFinder);
      final afterTransform = tester.widget<Transform>(
        find.ancestor(of: paintFinder, matching: find.byType(Transform)).first,
      );

      expect(identical(afterPaint, beforePaint), isTrue);
      expect(afterTransform.transform, isNot(beforeTransform.transform));
    },
  );

  testWidgets(
    'fullscreen gate, ticker policy and lifecycle stop ambient movement',
    (tester) async {
      Matrix4 cloudTransform() => tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('app-ambient-cloud-0')),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;

      await tester.pumpWidget(
        _host(
          const PlaybackPreferences(),
          disableAnimations: false,
          animationEnabled: false,
        ),
      );
      final fullscreenPaused = cloudTransform();
      await tester.pump(const Duration(seconds: 1));
      expect(cloudTransform(), fullscreenPaused);

      await tester.pumpWidget(
        _host(
          const PlaybackPreferences(),
          disableAnimations: false,
          tickerEnabled: false,
        ),
      );
      final tickerDisabled = cloudTransform();
      await tester.pump(const Duration(seconds: 1));
      expect(cloudTransform(), tickerDisabled);

      await tester.pumpWidget(
        _host(const PlaybackPreferences(), disableAnimations: false),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final paused = cloudTransform();
      await tester.pump(const Duration(seconds: 1));
      expect(cloudTransform(), paused);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(cloudTransform(), isNot(paused));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  test('motion presets stay within the 12, 18 and 24 FPS ceilings', () {
    expect(
      appAmbientFrameInterval(PlayerAmbientMotion.slow),
      const Duration(milliseconds: 84),
    );
    expect(
      appAmbientFrameInterval(PlayerAmbientMotion.normal),
      const Duration(milliseconds: 56),
    );
    expect(
      appAmbientFrameInterval(PlayerAmbientMotion.fast),
      const Duration(milliseconds: 42),
    );
  });

  test(
    'opt-in 4K static cloud rasterization stays bounded',
    () {
      final stopwatch = Stopwatch()..start();
      for (var cloud = 0; cloud < 4; cloud++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        AppAmbientCloudPainter(
          hue: cloud.isEven ? 215 : 285,
          intensity: 0.55,
          alpha: 0.62,
        ).paint(canvas, const Size(3840, 2160));
        recorder.endRecording().dispose();
      }
      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    },
    skip: _runAmbient4kPerf
        ? false
        : 'Enable with --dart-define=AMBIENT_4K_PERF=true',
  );
}
