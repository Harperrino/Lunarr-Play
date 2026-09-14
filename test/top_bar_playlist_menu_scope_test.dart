import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_catalog_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/app/widgets/top_bar_playlist_menu.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets('All-active menu renders exactly one selected radio entry', (
    tester,
  ) async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        playlistsStreamProvider.overrideWith((ref) => Stream.value(_playlists)),
        selectedPlaylistIdProvider.overrideWith((ref) => 1),
        playlistCatalogScopeProvider.overrideWith(
          (ref) => const PlaylistCatalogScope.allActive(),
        ),
        inactivePlaylistIdsProvider.overrideWith(
          _EmptyInactivePlaylistIdsNotifier.new,
        ),
        playlistSyncNotifierProvider.overrideWith(
          _ReadyPlaylistSyncNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TopBarPlaylistMenu(availableWidth: 1300),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('All active playlists'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(
      find.byIcon(Icons.radio_button_unchecked_rounded),
      findsNWidgets(_playlists.length),
    );
  });

  testWidgets('selecting an inactive playlist does not activate it', (
    tester,
  ) async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        playlistsStreamProvider.overrideWith((ref) => Stream.value(_playlists)),
        selectedPlaylistIdProvider.overrideWith((ref) => 1),
        playlistCatalogScopeProvider.overrideWith(
          (ref) => const PlaylistCatalogScope.single(1),
        ),
        inactivePlaylistIdsProvider.overrideWith(
          _SecondInactivePlaylistIdsNotifier.new,
        ),
        playlistSyncNotifierProvider.overrideWith(
          _ReadyPlaylistSyncNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            scrollbars: false,
          ),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TopBarPlaylistMenu(availableWidth: 1300),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(container.read(selectedPlaylistIdProvider), 2);
    expect(
      container.read(playlistCatalogScopeProvider),
      const PlaylistCatalogScope.single(2),
    );
    expect(
      container.read(inactivePlaylistIdsProvider).valueOrNull,
      contains(2),
    );
    expect(find.text('Second'), findsOneWidget);
  });
}

class _ReadyPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _EmptyInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

class _SecondInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{2};
}

final _playlists = [
  Playlist(
    id: 1,
    name: 'First',
    type: 'm3u',
    urlOrHost: 'https://example.invalid/first.m3u',
    createdAt: DateTime(2026, 7, 1),
  ),
  Playlist(
    id: 2,
    name: 'Second',
    type: 'm3u',
    urlOrHost: 'https://example.invalid/second.m3u',
    createdAt: DateTime(2026, 7, 1),
  ),
];
