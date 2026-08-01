import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_details_view.dart';

import 'jellyfin_test_helpers.dart';

const _movie = JellyfinItem(
  id: 'movie-1',
  name: 'Test Movie',
  type: 'Movie',
  productionYear: 2024,
  runTimeTicks: 54000000000,
  overview: 'A test movie overview.',
  playbackPositionTicks: 27000000000,
);

const _series = JellyfinItem(
  id: 'series-1',
  name: 'Test Series',
  type: 'Series',
  productionYear: 2023,
  overview: 'A test series overview.',
);

const _episode = JellyfinItem(
  id: 'episode-1',
  name: 'Test Episode',
  type: 'Episode',
  seriesName: 'Test Series',
  seasonNumber: 1,
  episodeNumber: 2,
  runTimeTicks: 2400000000,
  overview: 'An episode overview.',
);

void main() {
  testWidgets('movie detail shows meta, resume state and a disabled play', (
    tester,
  ) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(connection: jellyfinTestConnection, item: _movie),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Movie'), findsWidgets);
    expect(find.text('2024 · 1 h 30 min'), findsOneWidget);
    expect(find.text('A test movie overview.'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    final play = find.widgetWithText(FilledButton, 'Play');
    expect(play, findsOneWidget);
    expect(tester.widget<FilledButton>(play).onPressed, isNull);
  });

  testWidgets('series detail lists episodes grouped by season', (tester) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(connection: jellyfinTestConnection, item: _series),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Series'), findsWidgets);
    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    expect(find.text('Test Episode'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Play'), findsNothing);
  });

  testWidgets('episode detail shows the SxxExx meta and disabled play', (
    tester,
  ) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(connection: jellyfinTestConnection, item: _episode),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('S1 E2'), findsOneWidget);
    expect(find.text('Test Series'), findsOneWidget);
    expect(find.text('An episode overview.'), findsOneWidget);
    final play = find.widgetWithText(FilledButton, 'Play');
    expect(play, findsOneWidget);
    expect(tester.widget<FilledButton>(play).onPressed, isNull);
  });

  testWidgets('a broken episodes endpoint shows an inline retry', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(connection: jellyfinTestConnection, item: _series),
        transport: jellyfinHappyTransport(failEpisodes: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load from the Jellyfin server.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('movie without resume position hides the resume badge', (
    tester,
  ) async {
    const freshMovie = JellyfinItem(
      id: 'movie-2',
      name: 'Fresh Movie',
      type: 'Movie',
      productionYear: 2025,
      runTimeTicks: 36000000000,
    );
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(connection: jellyfinTestConnection, item: freshMovie),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume'), findsNothing);
    expect(find.text('2025 · 1 h 0 min'), findsOneWidget);
  });
}
