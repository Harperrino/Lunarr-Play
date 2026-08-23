import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_library_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_media_card.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

import 'jellyfin_test_helpers.dart';

const _library = JellyfinLibrary(
  id: 'library-1',
  name: 'Movies',
  collectionType: 'movies',
);

void main() {
  testWidgets(
    'poster decoding preserves source aspect ratio before cover crop',
    (tester) async {
      await tester.pumpWidget(
        jellyfinTestHost(
          const SizedBox(
            width: 150,
            child: JellyfinMediaCard(
              imageUrl: 'https://example.test/poster.jpg',
              title: 'Poster',
              semanticLabel: 'Poster',
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.fit, BoxFit.cover);
      expect(image.memCacheWidth, isNotNull);
      expect(image.memCacheHeight, isNull);
    },
  );

  testWidgets('library grid renders its items with counts', (tester) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinLibraryView(
          connection: jellyfinTestConnection,
          library: _library,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Test Movie'), findsOneWidget);
    expect(find.text('Test Series'), findsOneWidget);
    expect(find.text('A test movie overview.'), findsOneWidget);
    expect(find.text('A test series overview.'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    final posterRect = tester.getRect(find.byType(MediaPosterFrame).first);
    expect(posterRect.height / posterRect.width, closeTo(1.5, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid columns adapt to wide and 4K content widths', (
    tester,
  ) async {
    for (final size in [
      const Size(390, 800),
      const Size(1100, 800),
      const Size(2800, 1600),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        jellyfinTestHost(
          const JellyfinLibraryView(
            connection: jellyfinTestConnection,
            library: _library,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Test Movie'), findsOneWidget);
    }
  });

  testWidgets('a broken library shows an error with retry', (tester) async {
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinLibraryView(
          connection: jellyfinTestConnection,
          library: _library,
        ),
        transport: jellyfinHappyTransport(failLibraryItems: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load from the Jellyfin server.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an empty library shows the empty hint', (tester) async {
    final base = jellyfinEmptyHandler();
    await tester.pumpWidget(
      jellyfinTestHost(
        const JellyfinLibraryView(
          connection: jellyfinTestConnection,
          library: _library,
        ),
        transport: MockClient((request) async {
          if (request.url.path.endsWith('/Users/user-id-1/Items') &&
              request.url.queryParameters['ParentId'] == 'library-1') {
            return http.Response('{"Items": []}', 200);
          }
          return base(request);
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This library is empty.'), findsOneWidget);
  });
}
