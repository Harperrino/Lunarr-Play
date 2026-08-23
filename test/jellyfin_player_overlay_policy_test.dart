import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_episode_catalog.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_episode_overlay.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_episode_overlay_layer.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_player_shortcut_region.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';

import 'jellyfin_test_helpers.dart';
import 'support/localized_test_app.dart';

const _episodes = <JellyfinItem>[
  JellyfinItem(
    id: 'episode-1',
    name: 'Pilot',
    type: 'Episode',
    seriesId: 'series-1',
    seasonNumber: 1,
    episodeNumber: 1,
    overview: 'The first episode.',
  ),
  JellyfinItem(
    id: 'episode-2',
    name: 'Second',
    type: 'Episode',
    seriesId: 'series-1',
    seasonNumber: 1,
    episodeNumber: 2,
    overview: 'The second episode.',
  ),
  JellyfinItem(
    id: 'episode-3',
    name: 'Return',
    type: 'Episode',
    seriesId: 'series-1',
    seasonNumber: 2,
    episodeNumber: 1,
    overview: 'The next season.',
  ),
];

void main() {
  testWidgets('season dropdown remains inside a narrow episode panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LocalizedTestApp(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 720),
            textScaler: TextScaler.linear(2),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 376,
              height: 680,
              child: JellyfinPlayerEpisodeOverlay(
                connection: jellyfinOfflineTestConnection,
                imageService: const JellyfinImageService(),
                catalog: JellyfinEpisodeCatalog.fromEpisodes(_episodes),
                selectedSeason: 1,
                currentItemId: 'episode-1',
                loading: false,
                switchingEpisode: false,
                hasError: false,
                onSeasonSelected: (_) {},
                onSelect: (_) {},
                onRetry: () {},
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('jellyfin-episode-picker'));
    final selector = find.byKey(
      const ValueKey('jellyfin-player-season-selector-1'),
    );
    expect(panel, findsOneWidget);
    expect(selector, findsOneWidget);
    final panelRect = tester.getRect(panel);
    final selectorRect = tester.getRect(selector);
    expect(selectorRect.left, greaterThanOrEqualTo(panelRect.left));
    expect(selectorRect.right, lessThanOrEqualTo(panelRect.right));

    await tester.tap(selector);
    await tester.pumpAndSettle();

    final menuItems = find.byType(MenuItemButton).hitTestable();
    expect(menuItems, findsNWidgets(2));
    for (final element in menuItems.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      expect(rect.left, greaterThanOrEqualTo(panelRect.left - 0.1));
      expect(rect.right, lessThanOrEqualTo(panelRect.right + 0.1));
    }
  });

  testWidgets('dropdown hardens infinite width and long menu labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      LocalizedTestApp(
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: M3DropdownField<int>(
                key: const ValueKey('bounded-dropdown'),
                width: double.infinity,
                value: 1,
                label: const Text('Season'),
                leadingIcon: const Icon(Icons.video_library_rounded),
                entries: const [
                  DropdownMenuEntry(
                    value: 1,
                    label: 'A very long season name that must stay bounded',
                  ),
                  DropdownMenuEntry(value: 2, label: 'Season 2'),
                ],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdown = find.byKey(const ValueKey('bounded-dropdown'));
    expect(tester.getSize(dropdown).width, lessThanOrEqualTo(340));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden overlay is inert and unmounted after its exit', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(
      LocalizedTestApp(
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, isVisible, _) => JellyfinPlayerEpisodeOverlayLayer(
            visible: isVisible,
            child: Semantics(
              label: 'Episode overlay test',
              child: Focus(
                child: const SizedBox(
                  key: ValueKey('overlay-expensive-child'),
                  width: 100,
                  height: 100,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('overlay-expensive-child')), findsNothing);
    expect(_semanticsTree(tester), isNot(contains('Episode overlay test')));

    visible.value = true;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('overlay-expensive-child')),
      findsOneWidget,
    );
    expect(_semanticsTree(tester), contains('Episode overlay test'));

    visible.value = false;
    await tester.pump();
    expect(_semanticsTree(tester), isNot(contains('Episode overlay test')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overlay-expensive-child')), findsNothing);
    semantics.dispose();
  });

  testWidgets('open overlay leaves control keys local while Escape closes', (
    tester,
  ) async {
    var playPause = 0;
    var seekBackward = 0;
    var seekForward = 0;
    var controlActivations = 0;
    var escapes = 0;
    final controlFocus = FocusNode();
    addTearDown(controlFocus.dispose);

    Widget host(bool overlayVisible) => LocalizedTestApp(
      child: JellyfinPlayerShortcutRegion(
        episodeOverlayVisible: overlayVisible,
        onTogglePlayPause: () => playPause++,
        onToggleMute: () {},
        onSeekBackward: () => seekBackward++,
        onSeekForward: () => seekForward++,
        onEscape: () => escapes++,
        child: Center(
          child: overlayVisible
              ? FilledButton(
                  focusNode: controlFocus,
                  autofocus: true,
                  onPressed: () => controlActivations++,
                  child: const Text('Episode row'),
                )
              : Focus(
                  autofocus: true,
                  child: const SizedBox(width: 20, height: 20),
                ),
        ),
      ),
    );

    await tester.pumpWidget(host(false));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(playPause, 1);
    expect(seekBackward, 1);
    expect(seekForward, 1);

    await tester.pumpWidget(host(true));
    await tester.pump();
    controlFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);

    expect(controlActivations, 2);
    expect(playPause, 1);
    expect(seekBackward, 1);
    expect(seekForward, 1);
    expect(escapes, 1);
  });
}

String _semanticsTree(WidgetTester tester) => tester
    .binding
    .renderViews
    .first
    .owner!
    .semanticsOwner!
    .rootSemanticsNode!
    .toStringDeep();
