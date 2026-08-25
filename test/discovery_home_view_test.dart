import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_api_exception.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_home_view.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/theme/app_shapes.dart';
import 'package:m3uxtream_player/shared/theme/player_chrome_tokens.dart';

const _adultItem = DiscoveryMediaItem(
  id: 7,
  mediaType: DiscoveryMediaType.movie,
  title: 'Visible adult title',
  overview: 'A public discovery result.',
  adult: true,
  voteAverage: 7.5,
);

const _secondItem = DiscoveryMediaItem(
  id: 8,
  mediaType: DiscoveryMediaType.movie,
  title: 'Second title',
  overview: 'Second overview.',
);

class _Preferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async => const DiscoveryPreferences();

  @override
  Future<void> setSource(DiscoverySource source) async {
    state = AsyncData(DiscoveryPreferences(source: source));
  }
}

class _BothPreferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async =>
      const DiscoveryPreferences(seerrEndpoint: 'https://seerr.example.test');

  @override
  Future<void> setSource(DiscoverySource source) async {
    state = AsyncData(
      DiscoveryPreferences(
        source: source,
        seerrEndpoint: 'https://seerr.example.test',
      ),
    );
  }
}

class _Secrets extends DiscoverySecretsNotifier {
  @override
  Future<DiscoverySecrets> build() async =>
      const DiscoverySecrets(tmdbToken: 'fixture-token');
}

class _BothSecrets extends DiscoverySecretsNotifier {
  @override
  Future<DiscoverySecrets> build() async => const DiscoverySecrets(
    tmdbToken: 'fixture-token',
    seerrApiKey: 'fixture-key',
  );
}

class _Home extends DiscoveryHomeNotifier {
  @override
  Future<DiscoveryHomeFeed> build() async => DiscoveryHomeFeed(
    source: DiscoverySource.tmdb,
    heroItems: const <DiscoveryMediaItem>[_adultItem],
    shelves: const <DiscoveryShelf>[
      DiscoveryShelf(
        kind: DiscoveryShelfKind.popularMovies,
        items: <DiscoveryMediaItem>[_adultItem],
      ),
    ],
    fetchedAt: DateTime.utc(2026, 8, 23),
  );
}

class _MissingHome extends DiscoveryHomeNotifier {
  @override
  Future<DiscoveryHomeFeed> build() async => throw const DiscoveryApiException(
    DiscoveryFailureKind.missingConfiguration,
  );
}

class _MultiHome extends DiscoveryHomeNotifier {
  @override
  Future<DiscoveryHomeFeed> build() async => DiscoveryHomeFeed(
    source: DiscoverySource.tmdb,
    heroItems: const <DiscoveryMediaItem>[],
    shelves: const <DiscoveryShelf>[
      DiscoveryShelf(
        kind: DiscoveryShelfKind.popularMovies,
        items: <DiscoveryMediaItem>[_adultItem, _secondItem],
      ),
    ],
    fetchedAt: DateTime.utc(2026, 8, 24),
  );
}

class _Search extends DiscoverySearchNotifier {
  @override
  Future<DiscoverySearchState> build() async => const DiscoverySearchState();
}

class _Category extends DiscoveryCategoryNotifier {
  @override
  Future<DiscoveryCategoryState> build(DiscoveryShelfKind arg) async =>
      DiscoveryCategoryState(
        kind: arg,
        items: const [_adultItem],
        page: 1,
        totalPages: 1,
      );
}

Widget _host({
  required DiscoveryHomeNotifier Function() home,
  required VoidCallback onOpenSettings,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    discoveryPreferencesProvider.overrideWith(_Preferences.new),
    discoverySecretsProvider.overrideWith(_Secrets.new),
    discoveryHomeProvider.overrideWith(home),
    discoverySearchProvider.overrideWith(_Search.new),
    discoveryCategoryProvider.overrideWith(_Category.new),
    discoveryDetailsProvider.overrideWith((ref, item) async => item),
  ],
  child: MaterialApp(
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      extensions: const <ThemeExtension<dynamic>>[
        AppMotion.standard,
        AppShapes.standard,
        PlayerChromeTokens.standard,
      ],
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: DiscoveryHomeView(onOpenSettings: onOpenSettings),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('adult results remain visible and carry accessible labeling', (
    tester,
  ) async {
    await tester.pumpWidget(_host(home: _Home.new, onOpenSettings: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Visible adult title'), findsWidgets);
    expect(find.text('Adult'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Adult')), findsWidgets);
  });

  testWidgets('missing credentials show setup state and Settings action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      _host(home: _MissingHome.new, onOpenSettings: () => opened = true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up discovery'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    expect(opened, isTrue);
  });

  testWidgets('400 px layout supports 200 percent text without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _host(home: _Home.new, onOpenSettings: () {}, textScale: 2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('discovery-search-field')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('discovery-search-field')))
          .dx,
      lessThan(40),
    );
    expect(find.text('Visible adult title'), findsWidgets);
  });

  testWidgets('desktop search stays left aligned and width bounded', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(home: _Home.new, onOpenSettings: () {}));
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('discovery-search-field'));
    final rect = tester.getRect(search);
    expect(rect.left, lessThan(400));
    expect(rect.width, lessThanOrEqualTo(420));
  });

  testWidgets('selecting another title replaces the only detail pane', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(home: _MultiHome.new, onOpenSettings: () {}));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('Visible adult title')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-wide-details-movie-7')),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel(RegExp('Second title')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-wide-details-movie-7')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('discovery-wide-details-movie-8')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-wide-details-movie-8')),
      findsNothing,
    );
    expect(find.text('Second title'), findsOneWidget);
  });

  testWidgets('show all opens a category and Back restores Home', (
    tester,
  ) async {
    await tester.pumpWidget(_host(home: _Home.new, onOpenSettings: () {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('Popular movies'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Trending today'), findsOneWidget);
  });

  testWidgets('leaving Home atomically clears the transient search state', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        discoveryPreferencesProvider.overrideWith(_Preferences.new),
        discoverySecretsProvider.overrideWith(_Secrets.new),
        discoveryHomeProvider.overrideWith(_Home.new),
        discoverySearchProvider.overrideWith(_Search.new),
        discoveryCategoryProvider.overrideWith(_Category.new),
      ],
    );
    addTearDown(container.dispose);

    Widget app(Widget body) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: body)),
    );

    await tester.pumpWidget(app(DiscoveryHomeView(onOpenSettings: () {})));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('discovery-search-field')),
      'temporary',
    );
    await tester.pump();
    expect(
      container.read(discoverySearchProvider).valueOrNull?.query,
      'temporary',
    );

    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pump();
    await tester.pump();
    final reset = await container.read(discoverySearchProvider.future);
    expect(reset.query, isEmpty);
    expect(reset.items, isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('both configured services expose the toolbar source dropdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryPreferencesProvider.overrideWith(_BothPreferences.new),
          discoverySecretsProvider.overrideWith(_BothSecrets.new),
          discoveryHomeProvider.overrideWith(_Home.new),
          discoverySearchProvider.overrideWith(_Search.new),
          discoveryCategoryProvider.overrideWith(_Category.new),
        ],
        child: MaterialApp(
          home: Scaffold(body: DiscoveryHomeView(onOpenSettings: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-source-dropdown')),
      findsOneWidget,
    );
  });
}
