import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/movie_card.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_grid.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_metadata_row.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

const _movie = Channel(
  id: 42,
  playlistId: 1,
  name: 'Expressive Film',
  logo: null,
  groupName: 'Science Fiction',
  streamUrl: 'https://example.invalid/movie.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'vod',
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
    'movie card uses a tonal 2:3 poster and places metadata below it',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 180,
            child: MovieCard(channel: _movie, onTap: _noop, isSelected: true),
          ),
        ),
      );

      final poster = find.byType(MediaPosterFrame);
      final posterSize = tester.getSize(poster);
      expect(posterSize.width / posterSize.height, closeTo(2 / 3, 0.001));
      expect(find.byType(MediaMetadataRow), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MediaMetadataRow)).dy,
        greaterThan(tester.getBottomLeft(poster).dy),
      );
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
    'movie card exposes the existing tap callback through semantics',
    (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 180,
            child: MovieCard(channel: _movie, onTap: () => taps += 1),
          ),
        ),
      );

      final movie = find.bySemanticsLabel('Film: Expressive Film');
      expect(movie, findsOneWidget);
      await tester.tap(movie);
      expect(taps, 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'VOD grid preserves prep selection and lays out compact medium and wide',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final layout in <({double width, int columns})>[
        (width: 500, columns: 2),
        (width: 900, columns: 4),
        (width: 1600, columns: 7),
      ]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _host(
              SizedBox(
                width: layout.width,
                height: 700,
                child: const VodGrid(channels: <Channel>[_movie]),
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

      await tester.tap(find.byType(MovieCard));
      expect(
        container.read(playbackPrepTargetProvider)?.playbackChannel,
        _movie,
      );
    },
  );
}

void _noop() {}
