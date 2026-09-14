import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/player_chrome_tokens.dart';
import 'package:m3uxtream_player/shared/widgets/m3_transport_icon_button.dart';
import 'package:m3uxtream_player/shared/widgets/player_chrome.dart';

ThemeData _theme() => ThemeData.dark(useMaterial3: true).copyWith(
  extensions: const <ThemeExtension<dynamic>>[
    AppMotion.standard,
    AppShapes.standard,
    PlayerChromeTokens.standard,
  ],
);

Widget _host(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: _theme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('width classes share one compact, regular, and wide policy', () {
    const tokens = PlayerChromeTokens.standard;
    expect(
      playerChromeWidthClassFor(400, tokens),
      PlayerChromeWidthClass.compact,
    );
    expect(
      playerChromeWidthClassFor(650, tokens),
      PlayerChromeWidthClass.regular,
    );
    expect(playerChromeWidthClassFor(800, tokens), PlayerChromeWidthClass.wide);
  });

  testWidgets('regular chrome stacks primary controls above side clusters', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 640,
          child: PlayerChromeControlLayout(
            primary: const SizedBox(
              key: ValueKey('primary'),
              width: 180,
              height: 48,
            ),
            leading: const SizedBox(
              key: ValueKey('leading'),
              width: 180,
              height: 40,
            ),
            trailing: const SizedBox(
              key: ValueKey('trailing'),
              width: 180,
              height: 40,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.byKey(const ValueKey('primary'))).dy,
      lessThan(tester.getCenter(find.byKey(const ValueKey('leading'))).dy),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('leading'))).dy,
      tester.getCenter(find.byKey(const ValueKey('trailing'))).dy,
    );
  });

  testWidgets('wide chrome keeps all control clusters on one axis', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 1200,
          child: PlayerChromeControlLayout(
            primary: const SizedBox(
              key: ValueKey('primary'),
              width: 180,
              height: 48,
            ),
            leading: const SizedBox(
              key: ValueKey('leading'),
              width: 180,
              height: 40,
            ),
            trailing: const SizedBox(
              key: ValueKey('trailing'),
              width: 180,
              height: 40,
            ),
          ),
        ),
      ),
    );

    final primaryY = tester.getCenter(find.byKey(const ValueKey('primary'))).dy;
    expect(
      tester.getCenter(find.byKey(const ValueKey('leading'))).dy,
      primaryY,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('trailing'))).dy,
      primaryY,
    );
  });

  testWidgets('reduced motion makes chrome and shape transitions immediate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlayerChromeTransition(
              visible: false,
              child: SizedBox.square(dimension: 20),
            ),
            M3TransportIconButton(
              icon: Icons.play_arrow_rounded,
              tooltip: 'Play',
              onPressed: () {},
              size: 56,
              iconSize: 24,
              emphasized: true,
            ),
          ],
        ),
        reducedMotion: true,
      ),
    );

    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
      Duration.zero,
    );
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).duration,
      Duration.zero,
    );
    final button = tester.widget<IconButton>(find.byType(IconButton).last);
    expect(button.style?.animationDuration, Duration.zero);
  });
}
