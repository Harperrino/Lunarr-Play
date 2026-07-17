import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorite_channel_list.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_grid.dart';
import 'package:m3uxtream_player/features/xtream/widgets/vod_grid.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

List<Channel> _channels(String type) => List<Channel>.generate(
  30,
  (index) => Channel(
    id:
        index +
        (type == 'vod'
            ? 100
            : type == 'series'
            ? 200
            : 300),
    playlistId: 1,
    name: '$type item $index',
    logo: null,
    groupName: 'Group',
    streamUrl: 'https://example.invalid/$type/$index',
    isFavorite: type == 'live',
    isWatchLater: false,
    channelType: type,
  ),
);

final _vodChannels = _channels('vod');
final _seriesChannels = _channels('series');
final _favoriteChannels = _channels('live');

void main() {
  testWidgets('catalogue tabs keep independent PageStorage scroll positions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final hostKey = GlobalKey<_CatalogueScrollHostState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: _CatalogueScrollHost(key: hostKey),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const PageStorageKey<String>('vod-grid-scroll')),
      findsOneWidget,
    );
    final vodGrid = find.byType(GridView);
    await tester.drag(vodGrid, const Offset(0, -420));
    await tester.pumpAndSettle();
    final vodOffset = _scrollOffset(tester);
    expect(vodOffset, greaterThan(0));

    hostKey.currentState!.select(_CatalogueTab.series);
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(_scrollOffset(tester), 0);
    await tester.drag(find.byType(GridView), const Offset(0, -280));
    await tester.pumpAndSettle();
    final seriesOffset = _scrollOffset(tester);
    expect(seriesOffset, greaterThan(0));

    hostKey.currentState!.select(_CatalogueTab.favorites);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey<String>('favorite-channel-list-scroll')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    final favoriteOffset = _scrollOffset(tester);
    expect(favoriteOffset, greaterThan(0));

    hostKey.currentState!.select(_CatalogueTab.vod);
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester), closeTo(vodOffset, 0.01));

    hostKey.currentState!.select(_CatalogueTab.series);
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester), closeTo(seriesOffset, 0.01));

    hostKey.currentState!.select(_CatalogueTab.favorites);
    await tester.pumpAndSettle();
    expect(_scrollOffset(tester), closeTo(favoriteOffset, 0.01));
    expect(tester.takeException(), isNull);
  });
}

double _scrollOffset(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
}

enum _CatalogueTab { vod, series, favorites }

class _CatalogueScrollHost extends StatefulWidget {
  const _CatalogueScrollHost({super.key});

  @override
  State<_CatalogueScrollHost> createState() => _CatalogueScrollHostState();
}

class _CatalogueScrollHostState extends State<_CatalogueScrollHost> {
  final _pageStorageBucket = PageStorageBucket();
  var _tab = _CatalogueTab.vod;

  void select(_CatalogueTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(
        bucket: _pageStorageBucket,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final tab in _CatalogueTab.values)
                    TextButton(
                      onPressed: () => select(tab),
                      child: Text(tab.name),
                    ),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                _CatalogueTab.vod => VodGrid(
                  key: const ValueKey('vod-tab'),
                  channels: _vodChannels,
                ),
                _CatalogueTab.series => SeriesGrid(
                  key: const ValueKey('series-tab'),
                  channels: _seriesChannels,
                  onSeriesTap: _ignore,
                ),
                _CatalogueTab.favorites => FavoriteChannelList(
                  key: const ValueKey('favorites-tab'),
                  channels: _favoriteChannels,
                  selectedChannelId: null,
                  onActivate: _ignore,
                  onToggleFavorite: _ignore,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _ignore(Channel _) {}
}
