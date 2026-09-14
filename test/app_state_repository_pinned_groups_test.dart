import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/models/channel_sort_mode.dart';
import 'package:m3uxtream_player/core/services/channel_group_filter.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';

void main() {
  test('persists channel sort mode independently per playlist', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final repository = AppStateRepository(db);

    expect(
      await repository.getChannelSortMode(1),
      ChannelSortMode.providerDefault,
    );
    await repository.setChannelSortMode(1, ChannelSortMode.numeric);
    await repository.setChannelSortMode(2, ChannelSortMode.alphabetical);

    expect(await repository.getChannelSortMode(1), ChannelSortMode.numeric);
    expect(
      await repository.getChannelSortMode(2),
      ChannelSortMode.alphabetical,
    );
  });

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

  test('pinned provider reload preserves persistence and ordering', () async {
    final db = AppDatabase.executor(NativeDatabase.memory());
    addTearDown(() async => db.close());

    final repository = AppStateRepository(db);
    final container = ProviderContainer(
      overrides: [appStateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    container.read(selectedPlaylistIdProvider.notifier).state = 42;
    await container.read(pinnedGroupsProvider.future);
    await container
        .read(pinnedGroupsProvider.notifier)
        .toggleGroup(42, 'News', true);

    expect(container.read(pinnedGroupsProvider).valueOrNull, ['News']);
    await container.read(pinnedGroupsProvider.notifier).reloadForPlaylist(42);

    expect(container.read(pinnedGroupsProvider).valueOrNull, ['News']);
    expect(prioritizePinnedGroups(['Movies', 'News'], ['News']), [
      'News',
      'Movies',
    ]);
  });
}
