import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_hub_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/widgets/playlist_hub_screen.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

void main() {
  testWidgets(
    'Playlist Hub keeps InkWell as the only focus owner for expressive actions',
    (tester) async {
      final container = await _pumpPlaylistHub(tester);
      final semantics = tester.ensureSemantics();

      expect(find.byType(FilterChip), findsNWidgets(4));

      final liveChip = find.bySemanticsLabel('Live');
      expect(liveChip, findsOneWidget);
      expect(
        tester.getSemantics(liveChip),
        matchesSemantics(
          label: 'Live',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: false,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      semantics.dispose();
      container.dispose();
    },
  );

  testWidgets(
    'Playlist content chip activates on Enter without a dead second stop',
    (tester) async {
      final container = await _pumpPlaylistHub(tester);
      final semantics = tester.ensureSemantics();
      final liveChip = find.bySemanticsLabel('Live');

      await tester.tap(liveChip);
      await tester.pump();
      expect(
        container.read(selectedPlaylistContentFilterProvider),
        PlaylistContentFilter.live,
      );

      // Restore the state while retaining the focus acquired by the tap. If
      // A decorative wrapper must not own a second focus stop; Enter should
      // still reach the interactive surface below it.
      container.read(selectedPlaylistContentFilterProvider.notifier).state =
          PlaylistContentFilter.all;
      await tester.pump();
      Focus.of(tester.element(find.text('Live'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        container.read(selectedPlaylistContentFilterProvider),
        PlaylistContentFilter.live,
      );

      semantics.dispose();
      container.dispose();
    },
  );

  testWidgets('Global search tab traversal lands directly in the TextField', (
    tester,
  ) async {
    final leadingFocus = FocusNode(debugLabel: 'search-leading-focus');
    addTearDown(leadingFocus.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Focus(
                  focusNode: leadingFocus,
                  autofocus: true,
                  child: const SizedBox(width: 24, height: 24),
                ),
                const GlobalSearchField(width: 320),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.byType(AppSurface), findsNothing);

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(leadingFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(editableText.focusNode.hasFocus, isTrue);
  });
}

Future<ProviderContainer> _pumpPlaylistHub(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    overrides: [
      playlistsStreamProvider.overrideWith(
        (ref) => Stream.value(<Playlist>[_playlist]),
      ),
      channelsStreamProvider.overrideWith(
        (ref) => Stream.value(<Channel>[_channel]),
      ),
      inactivePlaylistIdsProvider.overrideWith(
        _EmptyInactivePlaylistIdsNotifier.new,
      ),
      hiddenGroupsProvider.overrideWith(_EmptyHiddenGroupsNotifier.new),
      pinnedGroupsProvider.overrideWith(_EmptyPinnedGroupsNotifier.new),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: const Scaffold(body: PlaylistHubScreen())),
    ),
  );
  await tester.pump();
  await tester.pump();
  return container;
}

class _EmptyHiddenGroupsNotifier extends HiddenGroupsNotifier {
  @override
  Future<Set<String>> build() async => const <String>{};
}

class _EmptyPinnedGroupsNotifier extends PinnedGroupsNotifier {
  @override
  Future<List<String>> build() async => const <String>[];
}

class _EmptyInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

final _playlist = Playlist(
  id: 1,
  name: 'Test playlist',
  type: 'm3u',
  urlOrHost: 'https://example.invalid/list.m3u',
  createdAt: DateTime(2026, 7, 1),
);

const _channel = Channel(
  id: 1,
  playlistId: 1,
  streamId: null,
  name: 'Test channel',
  logo: null,
  groupName: 'Tests',
  tvgId: null,
  streamUrl: 'https://example.invalid/live.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'live',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);
