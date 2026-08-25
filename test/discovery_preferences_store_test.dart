import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/core/repository/app_state_stores.dart';

void main() {
  late AppDatabase database;
  late AppStateValueStore values;

  setUp(() {
    database = AppDatabase.executor(NativeDatabase.memory());
    values = AppStateValueStore(database);
  });

  tearDown(() => database.close());

  test(
    'a new installation initializes Home as its startup destination',
    () async {
      final preferences = await DiscoveryStateStore(values).getPreferences();

      expect(preferences.startupDestination, AppStartupDestination.home);
      expect(
        await values.read(AppStateKeys.startupPreferenceInitialized),
        'true',
      );
      expect(await values.read(AppStateKeys.startupDestination), 'home');
    },
  );

  test(
    'an established installation keeps the historical Live startup',
    () async {
      await values.write('legacy_preference', 'present');

      final preferences = await DiscoveryStateStore(values).getPreferences();

      expect(preferences.startupDestination, AppStartupDestination.live);
      expect(await values.read(AppStateKeys.startupDestination), 'live');
    },
  );

  test(
    'stored source, endpoint, and startup choice persist without migration',
    () async {
      final store = DiscoveryStateStore(values);
      await store.setSource(DiscoverySource.seerr);
      await store.setSeerrEndpoint('  https://example.test/seerr  ');
      await store.setStartupDestination(AppStartupDestination.live);

      final preferences = await store.getPreferences();

      expect(preferences.source, DiscoverySource.seerr);
      expect(preferences.seerrEndpoint, 'https://example.test/seerr');
      expect(preferences.startupDestination, AppStartupDestination.live);
      expect(database.schemaVersion, 10);
    },
  );

  test('invalid enum values degrade to safe defaults', () async {
    await values.write(AppStateKeys.discoverySource, 'unknown');
    await values.write(AppStateKeys.startupDestination, 'unknown');
    await values.write(AppStateKeys.startupPreferenceInitialized, 'true');

    final preferences = await DiscoveryStateStore(values).getPreferences();

    expect(preferences.source, DiscoverySource.tmdb);
    expect(preferences.startupDestination, AppStartupDestination.live);
  });
}
