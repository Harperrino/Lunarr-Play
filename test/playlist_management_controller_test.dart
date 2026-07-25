import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/playlists/controllers/playlist_management_controller.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

void main() {
  test('management selection is independent from playback selection', () async {
    final database = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(database.close);
    final firstId = await database
        .into(database.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'First',
            type: 'm3u',
            urlOrHost: 'https://example.invalid/first.m3u',
          ),
        );
    final secondId = await database
        .into(database.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'Second',
            type: 'm3u',
            urlOrHost: 'https://example.invalid/second.m3u',
          ),
        );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final controller = container.read(playlistManagementControllerProvider);

    await controller.selectPlaylist(firstId, navigateToLive: false);
    controller.openManagement(playlistId: secondId);
    expect(container.read(selectedPlaylistIdProvider), firstId);
    expect(container.read(managedPlaylistIdProvider), secondId);
    expect(container.read(activeSidebarIndexProvider), shellPlaylistsTabIndex);

    await controller.setActive(secondId, false);
    expect(container.read(selectedPlaylistIdProvider), firstId);

    await controller.selectPlaylist(secondId, navigateToLive: false);
    expect(container.read(selectedPlaylistIdProvider), secondId);
    expect(
      container.read(inactivePlaylistIdsProvider).valueOrNull,
      isNot(contains(secondId)),
    );
  });
}
