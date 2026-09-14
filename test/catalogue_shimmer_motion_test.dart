import 'dart:async';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/app/composition/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/app/composition/xtream/widgets/series_screen.dart';
import 'package:m3uxtream_player/app/composition/xtream/widgets/vod_screen.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_shimmer.dart';

void main() {
  testWidgets('VOD shimmer disables animation for reduced motion', (
    tester,
  ) async {
    final controller = StreamController<List<Channel>>();
    addTearDown(controller.close);

    await _pumpLoadingScreen(
      tester,
      child: const VodScreen(),
      disableAnimations: true,
      streamOverride: vodChannelsStreamProvider.overrideWith(
        (ref) => controller.stream,
      ),
    );

    expect(_shimmerAnimationEnabled(tester), isFalse);
    await _disposeLoadingScreen(tester);
  });

  testWidgets('VOD shimmer animates when motion is enabled', (tester) async {
    final controller = StreamController<List<Channel>>();
    addTearDown(controller.close);

    await _pumpLoadingScreen(
      tester,
      child: const VodScreen(),
      disableAnimations: false,
      streamOverride: vodChannelsStreamProvider.overrideWith(
        (ref) => controller.stream,
      ),
    );

    expect(_shimmerAnimationEnabled(tester), isTrue);
    await _disposeLoadingScreen(tester);
  });

  testWidgets('Series shimmer disables animation for reduced motion', (
    tester,
  ) async {
    final controller = StreamController<List<Channel>>();
    addTearDown(controller.close);

    await _pumpLoadingScreen(
      tester,
      child: const SeriesScreen(),
      disableAnimations: true,
      streamOverride: seriesChannelsStreamProvider.overrideWith(
        (ref) => controller.stream,
      ),
    );

    expect(_shimmerAnimationEnabled(tester), isFalse);
    await _disposeLoadingScreen(tester);
  });

  testWidgets('Series shimmer animates when motion is enabled', (tester) async {
    final controller = StreamController<List<Channel>>();
    addTearDown(controller.close);

    await _pumpLoadingScreen(
      tester,
      child: const SeriesScreen(),
      disableAnimations: false,
      streamOverride: seriesChannelsStreamProvider.overrideWith(
        (ref) => controller.stream,
      ),
    );

    expect(_shimmerAnimationEnabled(tester), isTrue);
    await _disposeLoadingScreen(tester);
  });
}

Future<void> _pumpLoadingScreen(
  WidgetTester tester, {
  required Widget child,
  required bool disableAnimations,
  required Override streamOverride,
}) async {
  final database = AppDatabase.executor(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database), streamOverride],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _disposeLoadingScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

bool _shimmerAnimationEnabled(WidgetTester tester) {
  expect(find.byType(AppShimmer), findsOneWidget);
  final ticker = find.byKey(const ValueKey('app-shimmer-ticker-mode'));
  expect(ticker, findsOneWidget);
  return tester.widget<TickerMode>(ticker).enabled;
}
