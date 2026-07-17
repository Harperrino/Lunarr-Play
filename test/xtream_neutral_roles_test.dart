import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/parsers/xtream_parser.dart';
import 'package:m3uxtream_player/features/xtream/providers/series_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_detail_screen.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_card.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/theme/catalogue_surface_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';
import 'package:shimmer/shimmer.dart';

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

void main() {
  testWidgets('VOD card follows normal and high-contrast neutral roles', (
    tester,
  ) async {
    Future<void> pumpCard(bool highContrast) async {
      await tester.pumpWidget(
        _themeHost(
          highContrast: highContrast,
          child: SizedBox(
            width: 180,
            height: 360,
            child: VodCard(channel: _movie, onTap: _noop),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpCard(false);
    final normalColors = AppTheme.darkTheme.colorScheme;
    expect(find.byType(MediaPosterFrame), findsOneWidget);
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).level,
      AppSurfaceLevel.low,
    );
    expect(
      tester.widget<Text>(find.text('Expressive Film')).style?.color,
      AppTheme.darkTheme.textTheme.labelLarge?.color,
    );

    await pumpCard(true);
    final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(find.byType(MediaPosterFrame), findsOneWidget);
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).level,
      AppSurfaceLevel.low,
    );
    expect(
      tester.widget<Text>(find.text('Expressive Film')).style?.color,
      AppTheme.highContrastDarkTheme.textTheme.labelLarge?.color,
    );
    expect(normalColors.onSurface, isNot(highContrastColors.onSurface));
  });

  testWidgets('series episode shimmer follows high-contrast surface roles', (
    tester,
  ) async {
    final episodes = Completer<List<ParsedSeriesEpisode>>();
    addTearDown(() {
      if (!episodes.isCompleted) {
        episodes.complete(const <ParsedSeriesEpisode>[]);
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Series shimmer test opened database'),
          ),
          seriesEpisodesProvider.overrideWith(
            (ref, channelDbId) => episodes.future,
          ),
          seriesResumeProvider.overrideWith(
            (ref, channelDbId) => Future.value(null),
          ),
        ],
        child: _themeHost(
          highContrast: true,
          child: const SizedBox(
            width: 800,
            height: 600,
            child: SeriesDetailScreen(seriesChannel: _series, onBack: _noop),
          ),
        ),
      ),
    );
    await tester.pump();

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    final roles = CatalogueSurfaceRoles.fromTheme(
      AppTheme.highContrastDarkTheme,
    );
    final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
    final gradient = shimmer.gradient as LinearGradient;
    expect(gradient.colors.first, roles.shimmerBase);
    expect(gradient.colors[2], roles.shimmerHighlight);
    final tiles = find.descendant(
      of: find.byType(Shimmer),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == roles.shimmerTile,
      ),
    );
    expect(tiles, findsNWidgets(8));
    expect(
      ((tester.widget<Container>(tiles.first).decoration! as BoxDecoration)
          .color),
      colors.surfaceContainer,
    );
  });
}

Widget _themeHost({required bool highContrast, required Widget child}) {
  return MaterialApp(
    key: ValueKey<bool>(highContrast),
    theme: highContrast ? AppTheme.highContrastDarkTheme : AppTheme.darkTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void _noop() {}
