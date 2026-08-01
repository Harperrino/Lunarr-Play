@Tags(['native'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_media_card.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_controls.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_view.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_screen.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

import 'helpers/media_kit_test_init.dart';
import 'jellyfin_test_helpers.dart';

/// Taps the interactive poster frame of the card with the given title text.
Future<void> _tapCardPoster(WidgetTester tester, String title) async {
  final card = find.ancestor(
    of: find.text(title).first,
    matching: find.byType(JellyfinMediaCard),
  );
  await tester.tap(
    find.descendant(of: card, matching: find.byType(MediaPosterFrame)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ensureMediaKitForTests();
  });

  testWidgets(
    'item → playback info → direct play → player view → stop',
    (tester) async {
      jellyfinTallViewport(tester);

      await tester.pumpWidget(
        jellyfinTestHost(
          const JellyfinScreen(),
          connection: jellyfinOfflineTestConnection,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Home shelves are loaded (Libraries shelf contains the Movies card).
      expect(find.text('Libraries'), findsOneWidget);
      await _tapCardPoster(tester, 'Movies');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Library grid → movie details.
      expect(find.text('Test Movie'), findsWidgets);
      await _tapCardPoster(tester, 'Test Movie');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Details → Play.
      final playButton = find.widgetWithText(FilledButton, 'Play');
      expect(playButton, findsOneWidget);
      await tester.tap(playButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The Jellyfin player surface with its own controls is active.
      expect(find.byType(JellyfinPlayerView), findsOneWidget);
      expect(find.byType(JellyfinPlayerControls), findsOneWidget);

      // Stop returns to the details page and tears the player down.
      await tester.tap(find.byIcon(Icons.stop_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(JellyfinPlayerView), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    },
  );
}

