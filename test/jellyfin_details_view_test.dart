import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
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

MockClient _detailTransport(Map<String, dynamic> detailItem) {
  final happyHandler = jellyfinHappyHandler();
  return MockClient((request) async {
    if (RegExp(r'/Users/user-id-1/Items/[^/]+$').hasMatch(request.url.path)) {
      return http.Response(jsonEncode(detailItem), 200);
    }
    return happyHandler(request);
  });
}

MockClient _seriesTransportWithSeasons() {
  final happyHandler = jellyfinHappyHandler();
  return MockClient((request) async {
    if (request.url.path.contains('/Shows/') &&
        request.url.path.endsWith('/Episodes')) {
      return http.Response(
        jsonEncode({
          'Items': [
            jellyfinEpisodeJson(id: 's1e1', name: 'Season One First', episode: 1),
            jellyfinEpisodeJson(id: 's1e2', name: 'Season One Second', episode: 2),
            jellyfinEpisodeJson(
              id: 's2e1',
              name: 'Season Two First',
              season: 2,
              episode: 1,
            ),
          ],
        }),
        200,
      );
    }
    return happyHandler(request);
  });
}

void main() {
  testWidgets('movie detail shows Material 3 metadata, resume state and play', (
    tester,
  ) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _movie,
        ),
        transport: _detailTransport(
          jellyfinMovieJson(
            positionTicks: _movie.playbackPositionTicks,
            runtimeTicks: _movie.runTimeTicks,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Movie'), findsWidgets);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('1 h 30 min'), findsOneWidget);
    expect(find.text('A test movie overview.'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    final resume = find.widgetWithText(FilledButton, 'Resume');
    expect(resume, findsOneWidget);
    expect(tester.widget<FilledButton>(resume).onPressed, isNotNull);
    await tester.tap(resume);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JellyfinDetailsView)),
    );
    expect(container.read(jellyfinViewStackProvider).last, isA<JellyfinPlayerRoute>());
    final play = find.widgetWithText(FilledButton, 'Play');
    expect(play, findsOneWidget);
    expect(tester.widget<FilledButton>(play).onPressed, isNotNull);
  });

  testWidgets('series detail switches seasons with a Material 3 dropdown', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _series,
        ),
        transport: _seriesTransportWithSeasons(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Series'), findsWidgets);
    expect(find.byType(DropdownMenu<int>), findsOneWidget);
    expect(
      find.byKey(const ValueKey('jellyfin-season-selector')),
      findsOneWidget,
    );
    expect(find.text('Season 1'), findsWidgets);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    expect(find.text('Season One First'), findsOneWidget);
    expect(find.text('Season Two First'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Play'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('jellyfin-season-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 2').last);
    await tester.pumpAndSettle();

    expect(find.text('Season 2'), findsWidgets);
    expect(find.text('Season Two First'), findsOneWidget);
    expect(find.text('Season One First'), findsNothing);
  });

  testWidgets('episode detail shows the SxxExx metadata and play', (
    tester,
  ) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _episode,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('S1 E2'), findsOneWidget);
    expect(find.text('Test Series'), findsOneWidget);
    expect(find.text('An episode overview.'), findsOneWidget);
    final play = find.widgetWithText(FilledButton, 'Play');
    expect(play, findsOneWidget);
    expect(tester.widget<FilledButton>(play).onPressed, isNotNull);
  });

  testWidgets('season selector remains overflow-free on a narrow layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _series,
        ),
        transport: _seriesTransportWithSeasons(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('jellyfin-season-selector')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a broken episodes endpoint shows an inline retry', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _series,
        ),
        transport: jellyfinHappyTransport(failEpisodes: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load from the Jellyfin server.'),
      findsOneWidget,
    );
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
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: freshMovie,
        ),
        transport: _detailTransport(
          jellyfinMovieJson(
            id: freshMovie.id,
            name: freshMovie.name,
            year: freshMovie.productionYear,
            runtimeTicks: freshMovie.runTimeTicks,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume'), findsNothing);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('1 h 0 min'), findsOneWidget);
  });

  testWidgets(
    'detail endpoint supplies the backdrop missing from a shelf item',
    (tester) async {
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/Users/user-id-1/Items/movie-1')) {
          return http.Response(
            jsonEncode({
              'Id': 'movie-1',
              'Name': 'Test Movie',
              'Type': 'Movie',
              'BackdropImageTags': ['movie-backdrop'],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      await tester.pumpWidget(
        jellyfinTestHost(
          const JellyfinDetailsView(
            connection: jellyfinTestConnection,
            item: _movie,
          ),
          transport: transport,
        ),
      );
      await tester.pumpAndSettle();

      final backdrop = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage).first,
      );
      expect(backdrop.imageUrl, contains('/Items/movie-1/Images/Backdrop'));
      expect(backdrop.imageUrl, contains('tag=movie-backdrop'));
    },
  );

  testWidgets('detail shows server ratings, provider actions and facts', (
    tester,
  ) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _movie,
        ),
        transport: _detailTransport({
          'Id': 'movie-1',
          'Name': 'Test Movie',
          'Type': 'Movie',
          'ProductionYear': 2024,
          'RunTimeTicks': 54000000000,
          'Overview': 'A test movie overview.',
          'CommunityRating': 7.4,
          'CriticRating': 74,
          'ProviderIds': {'Imdb': 'tt123', 'Tmdb': '456'},
          'Genres': ['Drama', 'Fantasy'],
          'Studios': [
            {'Name': 'Lunarr Pictures'},
          ],
          'People': [
            {'Name': 'Director One', 'Type': 'Director'},
            {'Name': 'Writer One', 'Role': 'Writer'},
          ],
          'UserData': {'IsFavorite': true},
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Community'), findsOneWidget);
    expect(find.text('7.4'), findsOneWidget);
    expect(find.text('Critics'), findsOneWidget);
    expect(find.text('74%'), findsOneWidget);
    expect(find.text('IMDb'), findsOneWidget);
    expect(find.text('TMDb'), findsOneWidget);
    expect(find.textContaining('tt123'), findsNothing);
    expect(find.textContaining('456'), findsNothing);
    expect(find.byTooltip('Open IMDb'), findsOneWidget);
    expect(find.byTooltip('Open TMDb'), findsOneWidget);
    expect(find.text('Drama, Fantasy'), findsOneWidget);
    expect(find.text('Director One'), findsOneWidget);
    expect(find.text('Writer One'), findsOneWidget);
    expect(find.text('Lunarr Pictures'), findsOneWidget);
  });

  testWidgets('favorite action is optimistic and calls Jellyfin status API', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final transport = MockClient((request) async {
      requests.add(request);
      if (RegExp(r'/Users/user-id-1/Items/[^/]+$').hasMatch(request.url.path)) {
        return http.Response(jsonEncode(jellyfinMovieJson(id: 'movie-1')), 200);
      }
      if (request.url.path.endsWith('/FavoriteItems/movie-1')) {
        return http.Response('', 204);
      }
      return http.Response('not found', 404);
    });

    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _movie,
        ),
        transport: transport,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favorite'));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/FavoriteItems/movie-1'),
      ),
      isTrue,
    );
    expect(find.text('Remove favorite'), findsOneWidget);
  });

  testWidgets('compact detail layout keeps the poster at a 2:3 ratio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinDetailsView(
          connection: jellyfinTestConnection,
          item: _movie,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final poster = find.byKey(const ValueKey('jellyfin-detail-poster'));
    expect(poster, findsOneWidget);
    final size = tester.getSize(poster);
    expect(size.width / size.height, closeTo(2 / 3, 0.01));
  });

  testWidgets('wide detail layouts remain overflow-free', (tester) async {
    for (final size in const [
      Size(1080, 900),
      Size(1440, 1000),
      Size(2160, 1200),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        jellyfinTestHost(
          const JellyfinDetailsView(
            connection: jellyfinTestConnection,
            item: _movie,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
