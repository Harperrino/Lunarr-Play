import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_screen.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

void main() {
  testWidgets('VOD uses a tonal outer surface instead of a glass container', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: VodScreen()),
        ),
      ),
    );
    await tester.pump();

    final surface = find.byKey(const ValueKey('vod-screen-surface'));
    expect(surface, findsOneWidget);
    expect(tester.widget<AppSurface>(surface).level, AppSurfaceLevel.high);
  });
}
