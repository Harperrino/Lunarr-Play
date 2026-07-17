import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

void main() {
  test('persists pinned groups in AppStates with stable order', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final repository = AppStateRepository(db);

    await repository.setPinnedGroups(42, ['News', 'Sports', 'Movies']);

    expect(await repository.getPinnedGroups(42), ['News', 'Sports', 'Movies']);
  });

  test('returns empty list when no pinned groups exist', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final repository = AppStateRepository(db);

    expect(await repository.getPinnedGroups(99), isEmpty);
  });
}
