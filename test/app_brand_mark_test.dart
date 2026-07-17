import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/widgets/app_brand_mark.dart';

void main() {
  testWidgets('brand mark follows the active Material color scheme', (
    tester,
  ) async {
    final firstScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4B61D1),
    );
    final secondScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD14B82),
    );

    Future<void> pumpWith(ColorScheme colorScheme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
          home: const Scaffold(body: Center(child: AppBrandMark(size: 40))),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWith(firstScheme);
    final firstPainter =
        tester.widget<CustomPaint>(find.byKey(AppBrandMark.painterKey)).painter!
            as LunarrBrandMarkPainter;
    expect(firstPainter.color, firstScheme.primary);

    await pumpWith(secondScheme);
    final secondPainter =
        tester.widget<CustomPaint>(find.byKey(AppBrandMark.painterKey)).painter!
            as LunarrBrandMarkPainter;
    expect(secondPainter.color, secondScheme.primary);
    expect(secondPainter.color, isNot(firstPainter.color));
    expect(secondPainter.shouldRepaint(firstPainter), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('brand mark supports an explicit surface color', (tester) async {
    const overrideColor = Color(0xFF7BE6A2);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppBrandMark(size: 28, color: overrideColor)),
        ),
      ),
    );

    final painter =
        tester.widget<CustomPaint>(find.byKey(AppBrandMark.painterKey)).painter!
            as LunarrBrandMarkPainter;
    expect(painter.color, overrideColor);
    expect(tester.getSize(find.byType(AppBrandMark)), const Size.square(28));
    expect(tester.takeException(), isNull);
  });
}
