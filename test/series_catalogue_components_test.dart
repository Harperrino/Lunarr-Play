import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/xtream/widgets/episode_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_grid.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

const _series = Channel(
  id: 73,
  playlistId: 1,
  name: 'Expressive Serie',
  logo: null,
  groupName: 'Drama',
  streamUrl: 'https://example.invalid/series',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'series',
);

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets(
    'series card uses the shared tonal poster and metadata contract',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 180,
            child: SeriesCard(channel: _series, onTap: _noop, isSelected: true),
          ),
        ),
      );

      final poster = find.byType(MediaPosterFrame);
      final posterSize = tester.getSize(poster);
      expect(posterSize.width / posterSize.height, closeTo(2 / 3, 0.001));
      expect(find.byType(MediaMetadataRow), findsOneWidget);
      expect(find.bySemanticsLabel('Serie: Expressive Serie'), findsOneWidget);
      expect(
        tester.widget<AppSurface>(find.byType(AppSurface)).states,
        contains(WidgetState.selected),
      );
      expect(
        tester
            .widget<Stack>(
              find.ancestor(
                of: find.byType(MediaPosterFrame),
                matching: find.byType(Stack),
              ),
            )
            .clipBehavior,
        Clip.none,
      );
      expect(
        tester.widget<AppSurface>(find.byType(AppSurface)).elevationBehavior,
        AppElevationBehavior.elevatedCard,
      );
    },
  );

  testWidgets(
    'episode card preserves the activation callback on a tonal surface',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: EpisodeCard(
              title: 'The expressive episode',
              subtitle: 'S01E02',
              onTap: () => taps += 1,
            ),
          ),
        ),
      );

      expect(find.byType(MediaMetadataRow), findsOneWidget);
      expect(find.byType(AppSurface), findsOneWidget);
      await tester.tap(find.byType(EpisodeCard));
      expect(taps, 1);
    },
  );

  testWidgets('episode card exposes a focusable semantic action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var activations = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 360,
          child: EpisodeCard(
            title: 'The expressive episode',
            subtitle: 'S01E02',
            onTap: () => activations += 1,
          ),
        ),
      ),
    );

    final episode = find.bySemanticsLabel(RegExp('Episode:'));
    expect(episode, findsOneWidget);
    expect(
      tester
          .getSemantics(episode)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 1);
    semantics.dispose();
  });

  testWidgets('series grid preserves compact medium and wide breakpoints', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var tappedSeries = 0;

    for (final layout in <({double width, int columns})>[
      (width: 500, columns: 2),
      (width: 900, columns: 4),
      (width: 1600, columns: 7),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          child: _host(
            SizedBox(
              width: layout.width,
              height: 700,
              child: SeriesGrid(
                channels: const <Channel>[_series],
                onSeriesTap: (_) => tappedSeries += 1,
              ),
            ),
            textScale: 2,
          ),
        ),
      );
      await tester.pump();

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, layout.columns);
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byType(SeriesCard));
    expect(tappedSeries, 1);
  });
}

void _noop() {}
