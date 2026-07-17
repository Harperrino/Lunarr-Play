import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface_state_layer.dart';
import 'package:m3uxtream_player/shared/widgets/category_sidebar.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/features/favorites/widgets/favorite_channel_list.dart';
import 'package:m3uxtream_player/features/xtream/widgets/movie_card.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

const _channel = Channel(
  id: 101,
  playlistId: 1,
  name: 'Geometry Channel',
  groupName: 'Documentary',
  streamUrl: 'https://example.invalid/geometry.m3u8',
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

void _noop() {}

void main() {
  testWidgets('shared slots expose the D10 visual and hitbox contract', (
    tester,
  ) async {
    var activations = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Row(
          children: [
            const M3LeadingSlot(
              key: ValueKey('d10-leading-slot'),
              icon: Icons.live_tv_rounded,
            ),
            M3ActionSlot(
              key: const ValueKey('d10-action-slot'),
              icon: Icons.favorite_rounded,
              tooltip: 'Toggle favorite',
              semanticLabel: 'Toggle favorite',
              toggled: true,
              onPressed: () => activations++,
            ),
            const M3TabIconSlot(
              key: ValueKey('d10-tab-slot'),
              icon: Icons.movie_rounded,
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('d10-leading-slot'))),
      const Size(40, 40),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('d10-action-slot'))),
      const Size(48, 48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('d10-tab-slot'))),
      const Size(24, 24),
    );
    expect(
      tester.getSize(
        find.descendant(
          of: find.byKey(const ValueKey('d10-action-slot')),
          matching: find.byType(AppSurfaceStateLayer),
        ),
      ),
      const Size(40, 40),
    );

    final actionSemantics = tester.getSemantics(
      find.bySemanticsLabel('Toggle favorite'),
    );
    expect(actionSemantics.flagsCollection.isButton, isTrue);
    expect(actionSemantics.flagsCollection.isEnabled, Tristate.isTrue);
    expect(actionSemantics.flagsCollection.isToggled, Tristate.isTrue);

    final action = find.byKey(const ValueKey('d10-action-slot'));
    await tester.tapAt(tester.getTopLeft(action) + const Offset(46, 46));
    expect(activations, 1);
    semantics.dispose();
  });

  testWidgets('navigation and media rows keep a shared leading text axis', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 720,
          child: Column(
            children: [
              M3NavigationItem(
                label: 'Navigation one',
                icon: Icons.live_tv_rounded,
                onPressed: _noop,
              ),
              M3NavigationItem(
                label: 'Navigation two',
                leading: const SizedBox(width: 32, height: 32),
                onPressed: _noop,
              ),
              M3MediaListItem(
                title: 'Media one',
                leading: const Icon(Icons.tv_rounded),
                onActivate: _noop,
              ),
              M3MediaListItem(
                title: 'Media two',
                leading: const SizedBox(width: 36, height: 36),
                trailing: const M3LeadingSlot(
                  key: ValueKey('d10-media-trailing'),
                  icon: Icons.chevron_right,
                ),
                onActivate: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Navigation one')).dx,
      tester.getTopLeft(find.text('Navigation two')).dx,
    );
    expect(
      tester.getTopLeft(find.text('Media one')).dx,
      tester.getTopLeft(find.text('Media two')).dx,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('d10-media-trailing'))),
      const Size(40, 40),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('real category and favorite consumers survive D10 scale matrix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1680, 1140);
    addTearDown(tester.view.resetPhysicalSize);

    for (final dpr in <double>[1, 1.25, 1.5, 2]) {
      tester.view.devicePixelRatio = dpr;
      for (final textScale in <double>[1, 2]) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 840,
              height: 570,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 240,
                    child: CategorySidebar(
                      groups: const ['News', 'Documentary'],
                      selectedGroup: 'News',
                      onSelected: (_) {},
                      pinnedGroups: const ['Documentary'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FavoriteChannelList(
                      channels: const [_channel],
                      selectedChannelId: _channel.id,
                      onActivate: (_) {},
                      onToggleFavorite: (_) {},
                    ),
                  ),
                ],
              ),
            ),
            textScale: textScale,
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'dpr=$dpr textScale=$textScale',
        );
        expect(find.byType(M3LeadingSlot), findsWidgets);
        expect(find.byType(M3ActionSlot), findsOneWidget);
      }
    }
  });

  testWidgets('poster actions stay contained by the shared poster frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 180,
          child: MovieCard(
            channel: _channel.copyWith(channelType: 'vod'),
            onTap: _noop,
            posterAction: const M3ActionSlot(
              key: ValueKey('d10-poster-action'),
              icon: Icons.bookmark_border_rounded,
            ),
          ),
        ),
      ),
    );

    final poster = tester.getRect(find.byType(MediaPosterFrame));
    final action = tester.getRect(
      find.byKey(const ValueKey('d10-poster-action')),
    );
    expect(action.left, greaterThanOrEqualTo(poster.left));
    expect(action.top, greaterThanOrEqualTo(poster.top));
    expect(action.right, lessThanOrEqualTo(poster.right));
    expect(action.bottom, lessThanOrEqualTo(poster.bottom));
    expect(tester.takeException(), isNull);
  });
}
