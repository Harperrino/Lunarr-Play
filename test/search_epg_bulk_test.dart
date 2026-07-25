import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/search_catalog_entry.dart';
import 'package:m3uxtream_player/core/repository/epg_repository.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/search/models/channel_search_result.dart';
import 'package:m3uxtream_player/features/search/providers/category_search_providers.dart';

class _CountingEpgRepository extends EpgRepository {
  _CountingEpgRepository(super.database, this.entries);

  final List<EpgEntry> entries;
  int bulkQueryCount = 0;
  List<String>? queriedIds;

  @override
  Stream<List<EpgEntry>> watchEntriesInRangeForChannelIds(
    List<String> channelIds,
    DateTime start,
    DateTime end,
  ) {
    bulkQueryCount++;
    queriedIds = channelIds;
    return Stream.value(entries);
  }
}

ChannelSearchResult _result(int id, String epgId) {
  return ChannelSearchResult(
    entry: SearchCatalogEntry(
      channelId: id,
      playlistId: 1,
      type: 'live',
      name: 'Channel $id',
      epgChannelId: epgId,
    ),
    playlistId: 1,
    playlistName: 'Main',
    categoryName: 'News',
    resolvedEpgChannelId: epgId,
  );
}

void main() {
  test(
    'visible search channels use one bundled EPG query and minute state',
    () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.now();
      final epgRepository = _CountingEpgRepository(database, [
        EpgEntry(
          id: 1,
          channelId: 'epg-1',
          title: 'News now',
          startTime: now.subtract(const Duration(minutes: 5)),
          endTime: now.add(const Duration(minutes: 5)),
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          epgRepositoryProvider.overrideWithValue(epgRepository),
          searchVisibleChannelResultsProvider.overrideWithValue(
            List<ChannelSearchResult>.generate(
              13,
              (index) => _result(index + 1, 'epg-${index + 1}'),
            ),
          ),
          searchEpgMinuteTickProvider.overrideWith(
            (ref) => Stream.value(DateTime.now()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        searchEpgLinesProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);

      final lines = await container.read(searchEpgLinesProvider.future);

      expect(epgRepository.bulkQueryCount, 1);
      expect(epgRepository.queriedIds, hasLength(12));
      expect(epgRepository.queriedIds, contains('epg-12'));
      expect(lines[1]?.state, SearchEpgLineState.current);
      expect(lines[1]?.title, 'News now');
      expect(lines[2]?.state, SearchEpgLineState.noEpg);
    },
  );
}
