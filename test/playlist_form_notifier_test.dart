import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/playlist_form_providers.dart';

class _NoOpPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> sync(int playlistId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistFormNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.executor(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          playlistSyncNotifierProvider.overrideWith(
            _NoOpPlaylistSyncNotifier.new,
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns validation error for empty M3U fields', () async {
      final notifier = container.read(playlistFormNotifierProvider.notifier);

      final result = await notifier.addM3uPlaylist(name: '  ', urlOrPath: '');

      expect(result, isA<PlaylistFormValidationError>());
      expect(
        (result as PlaylistFormValidationError).message,
        contains('required'),
      );
    });

    test('inserts M3U playlist into in-memory database', () async {
      final notifier = container.read(playlistFormNotifierProvider.notifier);

      final result = await notifier.addM3uPlaylist(
        name: 'Test Playlist',
        urlOrPath: 'http://example.com/playlist.m3u',
      );

      expect(result, isA<PlaylistFormSuccess>());
      final success = result as PlaylistFormSuccess;
      expect(success.playlistName, 'Test Playlist');

      final playlists = await container
          .read(playlistRepositoryProvider)
          .getAllPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Test Playlist');
      expect(playlists.first.type, 'm3u');
      expect(playlists.first.urlOrHost, 'http://example.com/playlist.m3u');
    });

    test('updates an existing M3U playlist in the database', () async {
      final notifier = container.read(playlistFormNotifierProvider.notifier);

      final createResult = await notifier.addM3uPlaylist(
        name: 'Original Playlist',
        urlOrPath: 'http://example.com/original.m3u',
      );
      final created = createResult as PlaylistFormSuccess;

      final updateResult = await notifier.updatePlaylist(
        playlistId: created.playlistId,
        type: 'm3u',
        name: 'Updated Playlist',
        urlOrPath: 'http://example.com/updated.m3u',
      );

      expect(updateResult, isA<PlaylistFormSuccess>());

      final playlists = await container
          .read(playlistRepositoryProvider)
          .getAllPlaylists();
      expect(playlists.length, 1);
      expect(playlists.first.name, 'Updated Playlist');
      expect(playlists.first.urlOrHost, 'http://example.com/updated.m3u');
    });
  });
}
