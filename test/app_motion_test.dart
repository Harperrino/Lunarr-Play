import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/widgets/neural_background.dart';

const _testMotion = AppMotion(
  state: Duration(milliseconds: 40),
  content: Duration(milliseconds: 160),
  rail: Duration(milliseconds: 240),
  reduced: Duration.zero,
  standardCurve: Curves.linear,
  emphasizedCurve: Curves.easeIn,
);

ThemeData _theme() {
  return ThemeData(
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[_testMotion],
  );
}

Widget _host({required bool disableAnimations, required Widget child}) {
  return MaterialApp(
    theme: _theme(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('AppMotion resolves themed and reduced durations from context', (
    tester,
  ) async {
    AppMotion? normal;
    AppMotion? reduced;

    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: Builder(
          builder: (context) {
            normal = context.appMotion;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(normal?.state, _testMotion.state);
    expect(normal?.content, _testMotion.content);
    expect(normal?.rail, _testMotion.rail);

    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        child: Builder(
          builder: (context) {
            reduced = AppMotion.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(reduced?.state, Duration.zero);
    expect(reduced?.content, Duration.zero);
    expect(reduced?.rail, Duration.zero);
    expect(reduced?.standardCurve, _testMotion.standardCurve);
  });

  testWidgets('NeuralBackground stops and resumes its ambient controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: const NeuralBackground(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    final animatedBuilder = find.descendant(
      of: find.byType(NeuralBackground),
      matching: find.byType(AnimatedBuilder),
    );
    final controller =
        tester.widget<AnimatedBuilder>(animatedBuilder).animation
            as AnimationController;
    expect(controller.isAnimating, isTrue);

    await tester.pumpWidget(
      _host(
        disableAnimations: true,
        child: const NeuralBackground(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    expect(
      identical(
        controller,
        tester.widget<AnimatedBuilder>(animatedBuilder).animation,
      ),
      isTrue,
    );
    expect(controller.isAnimating, isFalse);

    await tester.pumpWidget(
      _host(
        disableAnimations: false,
        child: const NeuralBackground(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    expect(controller.isAnimating, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
