import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';

void main() {
  test('close is idempotent and can be called twice safely', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());

    await db.close();
    await db.close();

    expect(true, isTrue);
  });
}
