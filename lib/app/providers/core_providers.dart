import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';

/// Global singleton for the Drift SQLite database connection.
/// Lives in the app layer — features must not instantiate [AppDatabase] directly.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    AppLogger.info('Database Provider: Closing Drift connection.');
    db.close();
  });
  return db;
});

/// Shared key-value persistence (AppStates table).
final appStateRepositoryProvider = Provider<AppStateRepository>((ref) {
  return AppStateRepository(ref.watch(databaseProvider));
});
