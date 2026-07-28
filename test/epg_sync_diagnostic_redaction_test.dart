import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/epg_sync_service.dart';

void main() {
  test('EPG sync logs source type without raw URL or local path', () async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    AppLogger.clearHistory();
    AppLogger.setConsoleOutputEnabledForTests(false);
    addTearDown(() => AppLogger.setConsoleOutputEnabledForTests(true));
    final service = EpgSyncService(
      EpgRepository(database),
      PlaylistRepository(database),
    );
    const source = r'C:\Users\sentinel\Private Folder\missing-guide.xml';

    await expectLater(
      service.syncEpg(playlistId: 1, urlOrFilePath: source),
      throwsA(anything),
    );

    final output = AppLogger.recentEvents
        .map((entry) => '${entry.message} ${entry.error} ${entry.stackTrace}')
        .join('\n');
    expect(output, contains('source: local'));
    expect(output, isNot(contains(source)));
    expect(output, isNot(contains('sentinel')));
    expect(output, contains('[LOCAL_PATH]'));
  });
}
