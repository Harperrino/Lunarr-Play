@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';

Widget _goldenScene() => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('golden-boundary'),
      child: Center(
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Standard'),
                const SizedBox(key: ValueKey('standard-gap'), height: 4),
                const M3ExpressiveSlider(
                  key: ValueKey('standard'),
                  value: 0.42,
                  onChanged: _noop,
                ),
                const Text('Hover'),
                const M3ExpressiveSlider(
                  key: ValueKey('hover'),
                  value: 0.58,
                  onChanged: _noop,
                ),
                const Text('Focus'),
                const M3ExpressiveSlider(
                  key: ValueKey('focus'),
                  value: 0.34,
                  onChanged: _noop,
                ),
                const Text('Pressed'),
                const M3ExpressiveSlider(
                  key: ValueKey('pressed'),
                  value: 0.72,
                  onChanged: _noop,
                ),
                const Text('Disabled'),
                const M3ExpressiveSlider(
                  key: ValueKey('disabled'),
                  value: 0.5,
                  enabled: false,
                  onChanged: _noop,
                ),
                const Text('Buffer'),
                const M3ExpressiveSlider(
                  key: ValueKey('buffer'),
                  value: 0.32,
                  bufferedValue: 0.8,
                  onChanged: _noop,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void _noop(double _) {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M3 Expressive slider states match the visual contract', (
    tester,
  ) async {
    await tester.pumpWidget(_goldenScene());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getRect(find.byKey(const ValueKey('hover'))).center,
    );
    await tester.tap(find.byKey(const ValueKey('focus')));

    final pressedGesture = await tester.startGesture(
      tester.getRect(find.byKey(const ValueKey('pressed'))).center,
    );
    await tester.pump();

    // The explicit boundary keeps this golden independent from platform
    // window chrome and captures only the slider state scene.
    await expectLater(
      find.byKey(const ValueKey('golden-boundary')),
      matchesGoldenFile('goldens/m3_expressive_slider_states.png'),
    );

    await pressedGesture.up();
    await mouse.removePointer();
  });
}
