import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_settings_card.dart';

class _SeerrPreferences extends DiscoveryPreferencesNotifier {
  @override
  Future<DiscoveryPreferences> build() async => const DiscoveryPreferences(
    source: DiscoverySource.seerr,
    seerrEndpoint: 'http://192.168.1.20:5055/base',
  );
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
}
