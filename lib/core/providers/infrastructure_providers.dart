import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/search/search_index_repository.dart';
import 'package:m3uxtream_player/core/services/app_lifecycle_gate.dart';
import 'package:m3uxtream_player/core/services/database_health_controller.dart';

final appLifecycleGateProvider = Provider<AppLifecycleGate>((ref) {
  return AppLifecycleGate();
});

/// Global singleton for the Drift SQLite database connection.
/// Lives in the app layer — features must not instantiate [AppDatabase] directly.
final databaseProvider = Provider<AppDatabase>((ref) {
  // Drift is closed only by AppShutdownController. Provider disposal can
  // happen while a stream/listener is still unwinding and must not race the
  // connection close.
  return AppDatabase(health: ref.watch(databaseHealthProvider.notifier));
});

/// Shared key-value persistence (AppStates table).
final appStateRepositoryProvider = Provider<AppStateRepository>((ref) {
  return AppStateRepository(
    ref.watch(databaseProvider),
    lifecycleGate: ref.watch(appLifecycleGateProvider),
  );
});

/// Persistent SQLite search boundary shared by sync, bootstrap, and UI.
final searchIndexRepositoryProvider = Provider<SearchIndexRepository>((ref) {
  final repository = SearchIndexRepository(
    ref.watch(databaseProvider),
    lifecycleGate: ref.watch(appLifecycleGateProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
