import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

void main() {
  test('interval values have stable labels and storage values', () {
    expect(EpgRefreshInterval.manual.label, 'Manuell');
    expect(EpgRefreshInterval.hours6.duration, const Duration(hours: 6));
    expect(EpgRefreshInterval.hours12.storageValue, 'hours12');
    expect(
      EpgRefreshInterval.fromStorage('unknown'),
      EpgRefreshInterval.manual,
    );
  });

  test(
    'interval preference persists per playlist and clears cleanly',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = AppStateRepository(database);

      expect(
        await repository.getEpgRefreshInterval(42),
        EpgRefreshInterval.manual,
      );
      await repository.setEpgRefreshInterval(42, EpgRefreshInterval.hours24);
      expect(
        await repository.getEpgRefreshInterval(42),
        EpgRefreshInterval.hours24,
      );

      await repository.clearEpgRefreshInterval(42);
      expect(
        await repository.getEpgRefreshInterval(42),
        EpgRefreshInterval.manual,
      );
    },
  );
}
