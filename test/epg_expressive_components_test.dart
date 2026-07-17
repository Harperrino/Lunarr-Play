import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/services/epg_matching_service.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_grid.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_grid_frame.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_now_marker.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_program_cell.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

EpgEntry _entry() => EpgEntry(
  id: 1,
  channelId: 'example.channel',
  title: 'Aktuelle Sendung',
  description: null,
  startTime: DateTime(2026, 7, 13, 10),
  endTime: DateTime(2026, 7, 13, 11),
);

Channel _channel() => const Channel(
  id: 1,
  playlistId: 1,
  streamId: null,
  name: 'Testkanal',
  logo: null,
  groupName: 'Tests',
  tvgId: 'example.channel',
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'live',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);

void main() {
  testWidgets(
    'live programme uses a tonal surface with explicit live semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 420,
            height: 80,
            child: Stack(
              children: [
                EpgProgramCell(
                  entry: _entry(),
                  windowStart: DateTime(2026, 7, 13, 9),
                  windowEnd: DateTime(2026, 7, 13, 12),
                  pixelsPerMinute: 2,
                  isLive: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AppSurface), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Live jetzt: Aktuelle Sendung')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.widget<AppSurface>(find.byType(AppSurface)).states,
        contains(WidgetState.focused),
      );
      semantics.dispose();
    },
  );

  testWidgets('current time marker carries text and semantic meaning', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host(const EpgNowMarker()));

    expect(find.text('JETZT'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(EpgNowMarker)),
      matchesSemantics(label: 'Jetzt, aktuelle Zeit im Programm'),
    );
    semantics.dispose();
  });

  testWidgets('desktop grid keeps timeline rows and now marker scrollable', (
    tester,
  ) async {
    final now = DateTime.now();
    final entry = EpgEntry(
      id: 2,
      channelId: 'example.channel',
      title: 'Laufende Sendung',
      description: null,
      startTime: now.subtract(const Duration(minutes: 10)),
      endTime: now.add(const Duration(minutes: 20)),
    );
    final row = EpgGridRowData(
      channel: _channel(),
      matchStatus: EpgMatchStatus.matched,
      resolvedEpgChannelId: 'example.channel',
      programs: [entry],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          epgGridRowsProvider.overrideWithValue([row]),
        ],
        child: _host(
          const SizedBox(width: 1200, height: 600, child: EpgGrid()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(EpgGridFrame), findsOneWidget);
    expect(find.byType(EpgProgramCell), findsOneWidget);
    expect(find.byType(EpgNowMarker), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -30));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop EPG frame increases its tonal gutter at wide breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final layout in <({double width, double gutter})>[
        (width: 720, gutter: 12),
        (width: 1200, gutter: 16),
      ]) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: layout.width,
              height: 400,
              child: const EpgGridFrame(child: SizedBox.expand()),
            ),
          ),
        );
        await tester.pump();

        final surface = tester.widget<AppSurface>(
          find.byKey(const ValueKey('epg-grid-surface')),
        );
        expect(surface.padding, EdgeInsets.all(layout.gutter));
        expect(surface.level, AppSurfaceLevel.standard);
      }
    },
  );
}
