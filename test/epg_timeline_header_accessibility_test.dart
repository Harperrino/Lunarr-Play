import 'dart:ui' show SemanticsAction;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/composition/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/app/composition/epg/widgets/epg_timeline_header.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets('EPG resize handles expose semantic and keyboard adjustments', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                height: 36,
                child: EpgTimelineHeader(
                  windowStart: DateTime(2026, 7, 13, 10),
                  windowEnd: DateTime(2026, 7, 13, 11),
                  timelineWidth: 120,
                  pixelsPerMinute: epgGridPixelsPerMinuteDefault,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final handle = find.bySemanticsLabel('Adjust time column width').first;
    final semanticsData = tester.getSemantics(handle).getSemanticsData();
    expect(semanticsData.hasAction(SemanticsAction.increase), isTrue);
    expect(semanticsData.hasAction(SemanticsAction.decrease), isTrue);

    tester.semantics.increase(
      find.semantics.byLabel('Adjust time column width').first,
    );
    await tester.pump();
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteDefault + 0.25,
    );

    tester.semantics.decrease(
      find.semantics.byLabel('Adjust time column width').first,
    );
    await tester.pump();
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteDefault,
    );

    final handleCenter =
        tester.getTopLeft(find.byType(EpgTimelineHeader)) +
        const Offset(56, 18);
    await tester.tapAt(handleCenter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteDefault + 0.25,
    );
    semantics.dispose();
  });
}
