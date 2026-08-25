import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/api/discovery_http_client.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_settings_card.dart';

class _SeerrPreferences extends DiscoveryPreferencesNotifier {
  _SeerrPreferences({this.confirmedEndpoint = ''});

  String confirmedEndpoint;
  final configurations = <({String endpoint, String confirmedHttpEndpoint})>[];

  @override
  Future<DiscoveryPreferences> build() async => DiscoveryPreferences(
    source: DiscoverySource.seerr,
    seerrEndpoint: 'http://192.168.1.20:5055/base',
    seerrHttpConfirmedEndpoint: confirmedEndpoint,
  );

  @override
  Future<void> setSeerrHttpConfirmedEndpoint(String endpoint) async {
    confirmedEndpoint = endpoint;
    state = AsyncData(
      (state.requireValue).copyWith(seerrHttpConfirmedEndpoint: endpoint),
    );
  }

  @override
  Future<void> setSeerrConfiguration({
    required String endpoint,
    required String confirmedHttpEndpoint,
  }) async {
    configurations.add((
      endpoint: endpoint,
      confirmedHttpEndpoint: confirmedHttpEndpoint,
    ));
    state = AsyncData(
      state.requireValue.copyWith(
        seerrEndpoint: endpoint,
        seerrHttpConfirmedEndpoint: confirmedHttpEndpoint,
      ),
    );
  }

  @override
  Future<void> setSource(DiscoverySource source) async {
    state = AsyncData(state.requireValue.copyWith(source: source));
  }

  @override
  Future<void> setStartupDestination(AppStartupDestination destination) async {
    state = AsyncData(
      state.requireValue.copyWith(startupDestination: destination),
    );
  }
}

class _StoredSecrets extends DiscoverySecretsNotifier {
  @override
  Future<DiscoverySecrets> build() async => const DiscoverySecrets(
    tmdbToken: 'stored-tmdb-secret',
    seerrApiKey: 'stored-seerr-secret',
  );
}

void main() {
  testWidgets(
    'Seerr settings disclose key scope, HTTP risk, version, and attribution',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryPreferencesProvider.overrideWith(_SeerrPreferences.new),
            discoverySecretsProvider.overrideWith(_StoredSecrets.new),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: DiscoverySettingsCard(compact: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('administrator access to Seerr'),
        findsOneWidget,
      );
      expect(find.textContaining('unencrypted HTTP'), findsOneWidget);
      expect(find.textContaining('Seerr 3.1.0'), findsOneWidget);
      expect(find.textContaining('DPAPI-encrypted'), findsOneWidget);
      expect(find.textContaining('not endorsed or certified'), findsOneWidget);
      expect(find.text('stored-tmdb-secret'), findsNothing);
      expect(find.text('stored-seerr-secret'), findsNothing);
    },
  );

  testWidgets(
    'HTTP Seerr test requires endpoint-bound confirmation without exposing key',
    (tester) async {
      final preferences = _SeerrPreferences();
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/status')) {
          return http.Response(
            jsonEncode(<String, Object?>{'version': '3.1.0'}),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'page': 1,
            'totalPages': 1,
            'results': const <Object?>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveryPreferencesProvider.overrideWith(() => preferences),
            discoverySecretsProvider.overrideWith(_StoredSecrets.new),
            discoveryHttpClientProvider.overrideWithValue(
              DiscoveryHttpClient(transport),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: DiscoverySettingsCard(compact: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test connection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Confirm unencrypted Seerr connection'), findsOneWidget);
      expect(
        find.textContaining('transport encryption to 192.168.1.20:5055'),
        findsOneWidget,
      );
      expect(find.textContaining('stored-seerr-secret'), findsNothing);
      expect(requests, isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      await tester.tap(find.text('Test connection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(requests.first.headers.containsKey('X-Api-Key'), isFalse);
      expect(requests.last.headers['X-Api-Key'], 'stored-seerr-secret');
      expect(
        preferences.confirmedEndpoint,
        'http://192.168.1.20:5055/base/api/v1',
      );

      await tester.enterText(
        find.byKey(const ValueKey('discovery-seerr-endpoint-field')),
        'http://192.168.1.21:5055/base',
      );
      await tester.tap(find.text('Test connection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Confirm unencrypted Seerr connection'), findsOneWidget);
      expect(
        find.textContaining('transport encryption to 192.168.1.21:5055'),
        findsOneWidget,
      );
      expect(requests, hasLength(2));
    },
  );

  testWidgets('saving an HTTP Seerr endpoint also requires confirmation', (
    tester,
  ) async {
    final preferences = _SeerrPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoveryPreferencesProvider.overrideWith(() => preferences),
          discoverySecretsProvider.overrideWith(_StoredSecrets.new),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DiscoverySettingsCard(compact: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Confirm unencrypted Seerr connection'), findsOneWidget);
    expect(preferences.configurations, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(preferences.configurations, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(preferences.configurations, hasLength(2));
    expect(preferences.configurations.first.endpoint, isEmpty);
    expect(preferences.configurations.last, (
      endpoint: 'http://192.168.1.20:5055/base',
      confirmedHttpEndpoint: 'http://192.168.1.20:5055/base/api/v1',
    ));
  });
}
