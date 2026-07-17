import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_screen.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

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

    expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
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

    expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isTrue);
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

    expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
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

    expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isTrue);
  });
}

Future<void> _pumpLoadingScreen(
  WidgetTester tester, {
  required Widget child,
  required bool disableAnimations,
  required Override streamOverride,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [streamOverride],
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
