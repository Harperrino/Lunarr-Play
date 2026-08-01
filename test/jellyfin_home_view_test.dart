import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_home_view.dart';

import 'jellyfin_test_helpers.dart';

void main() {
  testWidgets('home shows shelves only for non-empty sections', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinHomeView(connection: jellyfinTestConnection, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Libraries'), findsOneWidget);
    expect(find.text('Test Movie'), findsWidgets);
    expect(find.text('Movies'), findsWidgets);
    expect(find.text('TV Shows'), findsOneWidget);
    expect(find.text('http://server:8096'), findsOneWidget);
  });

  testWidgets('a broken resume endpoint hides only that shelf', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinHomeView(connection: jellyfinTestConnection, onSignOut: () {}),
        transport: jellyfinHappyTransport(failResume: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue watching'), findsNothing);
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Libraries'), findsOneWidget);
  });

  testWidgets('a broken library list shows an error with retry', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    var failViews = true;
    final transport = MockClient((request) async {
      return jellyfinHappyHandler(failViews: failViews)(request);
    });
    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinHomeView(connection: jellyfinTestConnection, onSignOut: () {}),
        transport: transport,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load from the Jellyfin server.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Retry after the server recovers shows the shelves again.
    failViews = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Libraries'), findsOneWidget);
  });

  testWidgets('an empty home shows the empty hint instead of placeholders', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinHomeView(connection: jellyfinTestConnection, onSignOut: () {}),
        transport: MockClient(jellyfinEmptyHandler()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Continue watching'), findsNothing);
    expect(find.text('Libraries'), findsNothing);
  });

  testWidgets('sign out action is exposed on the home header', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      jellyfinTestHost(
        JellyfinHomeView(
          connection: jellyfinTestConnection,
          onSignOut: () => signedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    expect(signedOut, isTrue);
  });
}
