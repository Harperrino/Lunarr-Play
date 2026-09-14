import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_details_pane.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_trailer_launcher.dart';

const _trailer = DiscoveryTrailer(
  title: 'Official trailer',
  type: DiscoveryTrailerType.trailer,
  provider: DiscoveryTrailerProvider.youtube,
  official: true,
  key: 'Trailer01',
  watchUrl: 'https://www.youtube.com/watch?v=Trailer01',
);

const _item = DiscoveryMediaItem(
  id: 4,
  mediaType: DiscoveryMediaType.movie,
  title: 'Trailer movie',
  trailers: <DiscoveryTrailer>[_trailer],
);

const _secondTrailer = DiscoveryTrailer(
  title: 'Teaser',
  type: DiscoveryTrailerType.teaser,
  provider: DiscoveryTrailerProvider.youtube,
  official: false,
  key: 'Teaser02',
  watchUrl: 'https://www.youtube.com/watch?v=Teaser02',
);

class _Preferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async => const DiscoveryPreferences();
}

class _FakeTrailerLauncher implements DiscoveryTrailerLauncher {
  int calls = 0;
  DiscoveryTrailer? lastTrailer;

  @override
  Future<void> open(
    BuildContext context, {
    required DiscoveryTrailer trailer,
  }) async {
    calls++;
    lastTrailer = trailer;
  }
}

void main() {
  testWidgets(
    'details expose trailers through the injectable player boundary',
    (tester) async {
      final launcher = _FakeTrailerLauncher();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryPreferencesProvider.overrideWith(_Preferences.new),
            discoveryDetailsProvider.overrideWith((ref, item) async => item),
            discoveryTrailerLauncherProvider.overrideWithValue(launcher),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DiscoveryDetailsPane(item: _item)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open trailer'));
      await tester.pump();

      expect(launcher.calls, 1);
      expect(launcher.lastTrailer, same(_trailer));
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      final link = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.link == true,
        ),
      );
      expect(link.properties.link, isTrue);
    },
  );

  testWidgets('more trailers use the same external launcher', (tester) async {
    final launcher = _FakeTrailerLauncher();
    const item = DiscoveryMediaItem(
      id: 5,
      mediaType: DiscoveryMediaType.movie,
      title: 'Trailer collection',
      trailers: <DiscoveryTrailer>[_trailer, _secondTrailer],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryPreferencesProvider.overrideWith(_Preferences.new),
          discoveryDetailsProvider.overrideWith((ref, item) async => item),
          discoveryTrailerLauncherProvider.overrideWithValue(launcher),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DiscoveryDetailsPane(item: item)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<DiscoveryTrailer>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teaser'));
    await tester.pump();

    expect(launcher.calls, 1);
    expect(launcher.lastTrailer, same(_secondTrailer));
  });

  testWidgets('default launcher opens only validated HTTPS links', (
    tester,
  ) async {
    Uri? openedUri;
    final launcher = DefaultDiscoveryTrailerLauncher(
      launchExternalUrl: (uri) async {
        openedUri = uri;
        return true;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => launcher.open(context, trailer: _trailer),
              child: const Text('Launch'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();

    expect(openedUri, _trailer.validatedWatchUri);
  });

  testWidgets('invalid and failed trailer launches show a localized error', (
    tester,
  ) async {
    var calls = 0;
    final launcher = DefaultDiscoveryTrailerLauncher(
      launchExternalUrl: (_) async {
        calls++;
        return false;
      },
    );
    var trailer = const DiscoveryTrailer(
      title: 'Unsafe',
      type: DiscoveryTrailerType.trailer,
      provider: DiscoveryTrailerProvider.external,
      official: false,
      key: 'unsafe',
      watchUrl: 'http://example.com/trailer',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FilledButton(
              onPressed: () => launcher.open(context, trailer: trailer),
              onLongPress: () => setState(() => trailer = _trailer),
              child: const Text('Launch'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();
    expect(calls, 0);
    expect(
      find.text('The trailer could not be opened in your browser.'),
      findsOneWidget,
    );

    await tester.longPress(find.text('Launch'));
    await tester.pump();
    await tester.tap(find.text('Launch'));
    await tester.pump();
    expect(calls, 1);
    expect(
      find.text('The trailer could not be opened in your browser.'),
      findsWidgets,
    );
  });
}
