import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorite_channel_list.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorites_screen.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

const _favorite = Channel(
  id: 71,
  playlistId: 1,
  name: 'Expressiver Lieblingssender',
  groupName: 'Dokumentation',
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: true,
  isWatchLater: false,
  channelType: 'live',
);

Widget _host(Widget child, {double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: child),
    ),
  );
}

AppDatabase _failFastDatabase(Ref ref) {
  throw StateError('Favorites screen tests must not open the database');
}

ChannelFavoriteController _noOpFavoriteController(Ref ref) {
  return ChannelFavoriteController((_) async => false);
}

void main() {
  testWidgets('favorite live tile keeps tonal focus and activation at 200%', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    _FavoriteListTestHost.activations = 0;
    _FavoriteListTestHost.toggles = 0;

    await tester.pumpWidget(
      _host(
        const SizedBox(width: 360, height: 300, child: _FavoriteListTestHost()),
        textScale: 2,
      ),
    );

    expect(find.byKey(const ValueKey('favorite-channel-list')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Favorit: Expressiver Lieblingssender')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Aus Favoriten entfernen'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<AppSurface>(
            find.byKey(const ValueKey('favorite-channel-tile-71')),
          )
          .states,
      contains(WidgetState.focused),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(_FavoriteListTestHost.activations, 1);

    await tester.tap(find.byKey(const ValueKey('favorite-channel-tile-71')));
    expect(_FavoriteListTestHost.activations, 2);
    expect(
      tester
          .widget<AppSurface>(
            find.byKey(const ValueKey('favorite-channel-tile-71')),
          )
          .states,
      contains(WidgetState.selected),
    );

    await tester.tap(find.byKey(const ValueKey('channel-favorite-toggle-71')));
    await tester.pump();
    expect(_FavoriteListTestHost.toggles, 1);
    semantics.dispose();
  });

  testWidgets('screen keeps empty state separate from playlist navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(_failFastDatabase),
          channelFavoriteControllerProvider.overrideWith(
            _noOpFavoriteController,
          ),
        ],
        child: _host(const FavoritesScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('favorites-screen-surface')),
      findsOneWidget,
    );
    expect(find.text('Keine Playlist ausgewählt'), findsOneWidget);
  });

  testWidgets('screen reads the selected playlist stream without new storage', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(_failFastDatabase),
          selectedPlaylistIdProvider.overrideWith((ref) => 1),
          channelsStreamProvider.overrideWith(
            (ref) => Stream.value(const <Channel>[_favorite]),
          ),
          channelFavoriteControllerProvider.overrideWith(
            _noOpFavoriteController,
          ),
        ],
        child: _host(const FavoritesScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('favorite-channel-list')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('favorite-channel-tile-71')),
      findsOneWidget,
    );
  });

  testWidgets('removing a favorite updates the screen reactively', (
    tester,
  ) async {
    final channels = StreamController<List<Channel>>.broadcast();
    addTearDown(channels.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(_failFastDatabase),
          selectedPlaylistIdProvider.overrideWith((ref) => 1),
          channelsStreamProvider.overrideWith((ref) => channels.stream),
          channelFavoriteControllerProvider.overrideWith(
            (ref) => ChannelFavoriteController((_) async {
              channels.add(const <Channel>[
                Channel(
                  id: 71,
                  playlistId: 1,
                  name: 'Expressiver Lieblingssender',
                  groupName: 'Dokumentation',
                  streamUrl: 'https://example.invalid/live.m3u8',
                  isFavorite: false,
                  isWatchLater: false,
                  channelType: 'live',
                ),
              ]);
              return false;
            }),
          ),
        ],
        child: _host(const FavoritesScreen()),
      ),
    );
    channels.add(const <Channel>[_favorite]);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('favorite-channel-tile-71')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('channel-favorite-toggle-71')));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('favorite-channel-tile-71')),
      findsNothing,
    );
    expect(find.text('Noch keine Live-Favoriten'), findsOneWidget);
  });

  testWidgets(
    'favorite persistence errors are visible without leaking details',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(_failFastDatabase),
            selectedPlaylistIdProvider.overrideWith((ref) => 1),
            channelsStreamProvider.overrideWith(
              (ref) => Stream.value(const <Channel>[_favorite]),
            ),
            channelFavoriteControllerProvider.overrideWith(
              (ref) => ChannelFavoriteController(
                (_) async => throw StateError('private provider detail'),
              ),
            ),
          ],
          child: _host(const FavoritesScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('channel-favorite-toggle-71')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Favorit konnte nicht gespeichert werden.'),
        findsOneWidget,
      );
      expect(find.textContaining('example.invalid'), findsNothing);
    },
  );

  test('activation preserves select, open, then Live-tab order', () {
    final calls = <String>[];

    activateFavoriteLiveChannel(
      channel: _favorite,
      onSelectChannel: (channel) => calls.add('select:${channel.id}'),
      onOpenStream: (url) => calls.add('open:$url'),
      onShowLiveTab: () => calls.add('live-tab'),
    );

    expect(calls, ['select:71', 'open:${_favorite.streamUrl}', 'live-tab']);
  });
}

class _FavoriteListTestHost extends StatelessWidget {
  const _FavoriteListTestHost();

  static var activations = 0;
  static var toggles = 0;

  @override
  Widget build(BuildContext context) {
    return FavoriteChannelList(
      channels: const [_favorite],
      selectedChannelId: _favorite.id,
      onActivate: (_) => activations += 1,
      onToggleFavorite: (_) => toggles += 1,
    );
  }
}
