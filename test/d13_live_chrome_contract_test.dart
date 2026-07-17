import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/repository/app_state_repository.dart';
import 'package:m3uxtream_player/core/repository/playlist_repository.dart';
import 'package:m3uxtream_player/core/services/live_composition_geometry.dart';
import 'package:m3uxtream_player/core/services/live_layout_geometry.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_list_panel.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/theme/app_spacing.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';

class _D13PlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _D13EpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

class _D13InactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

class _D13HiddenGroupsNotifier extends HiddenGroupsNotifier {
  @override
  Future<Set<String>> build() async => const <String>{};
}

class _D13FakeDatabase extends Fake implements AppDatabase {}

class _D13PlaylistRepository extends PlaylistRepository {
  _D13PlaylistRepository(this.playlist) : super(_D13FakeDatabase());

  final Playlist playlist;

  @override
  Future<Playlist?> getPlaylistById(int playlistId) async => playlist;
}

class _D13AppStateRepository extends AppStateRepository {
  _D13AppStateRepository() : super(_D13FakeDatabase());

  @override
  Future<bool> isEpgReminderDismissed(int playlistId) async => false;
}

void main() {
  test('D13 sender panel token includes its fixed header contract', () {
    expect(LiveCompositionMetrics.channelPanelHeaderActionsWidth, 152);
    expect(
      LiveCompositionMetrics.minimumChannelPanelOuterWidth,
      LiveCompositionMetrics.panePadding * 2 +
          LiveCompositionMetrics.minimumChannelPanelInnerWidth,
    );
    expect(
      LiveLayoutMetrics.minimumChannelPanelOuterWidth,
      LiveCompositionMetrics.minimumChannelPanelOuterWidth,
    );
    expect(
      LiveCompositionMetrics.minimumChannelPanelOuterWidth,
      greaterThan(LiveCompositionMetrics.minimumChannelListContentWidth),
    );
  });

  testWidgets(
    'ChannelListPanel stays contained at the real 258.3-dp inner width',
    (tester) async {
      final playlist = Playlist(
        id: 1,
        name: 'A very long playlist name that must remain ellipsized safely',
        type: 'm3u',
        urlOrHost: 'https://example.invalid/live.m3u',
        createdAt: DateTime(2026, 7, 16),
      );
      final panelOuterWidth = LiveCompositionMetrics.panePadding * 2 + 258.3;

      for (final textScale in [1.0, 2.0]) {
        final selected = <String>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (ref) => throw StateError('D13 must not open the database'),
              ),
              playlistRepositoryProvider.overrideWithValue(
                _D13PlaylistRepository(playlist),
              ),
              appStateRepositoryProvider.overrideWithValue(
                _D13AppStateRepository(),
              ),
              selectedPlaylistIdProvider.overrideWith((ref) => 1),
              playlistsStreamProvider.overrideWith(
                (ref) => Stream.value(<Playlist>[playlist]),
              ),
              liveChannelsStreamProvider.overrideWith(
                (ref) => Stream.value(const <Channel>[]),
              ),
              hiddenGroupsProvider.overrideWith(_D13HiddenGroupsNotifier.new),
              inactivePlaylistIdsProvider.overrideWith(
                _D13InactivePlaylistIdsNotifier.new,
              ),
              playlistSyncNotifierProvider.overrideWith(
                _D13PlaylistSyncNotifier.new,
              ),
              epgSyncNotifierProvider.overrideWith(_D13EpgSyncNotifier.new),
              channelFavoriteControllerProvider.overrideWith(
                (ref) => ChannelFavoriteController((channelId) async => true),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: SizedBox(
                    width: panelOuterWidth,
                    height: 440,
                    child: ChannelListPanel(
                      headerActions: Wrap(
                        spacing:
                            LiveCompositionMetrics.channelPanelHeaderActionGap,
                        runSpacing:
                            LiveCompositionMetrics.channelPanelHeaderActionGap,
                        children: [
                          M3PaneToggleButton(
                            target: M3PaneTarget.categories,
                            expanded: true,
                            onPressed: () => selected.add('categories'),
                          ),
                          M3PaneToggleButton(
                            target: M3PaneTarget.channels,
                            expanded: true,
                            onPressed: () => selected.add('channels'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final panel = tester.getRect(find.byType(AppSurface));
        final actions = tester.widgetList<M3PaneToggleButton>(
          find.byType(M3PaneToggleButton),
        );
        expect(actions, hasLength(2));
        for (final action in actions) {
          final rect = tester.getRect(find.byWidget(action));
          expect(rect.height, 48);
          expect(rect.left, greaterThanOrEqualTo(panel.left));
          expect(rect.right, lessThanOrEqualTo(panel.right));
          expect(rect.top, greaterThanOrEqualTo(panel.top));
          expect(rect.bottom, lessThanOrEqualTo(panel.bottom));
        }
        expect(find.bySemanticsLabel('Kategorien einklappen'), findsOneWidget);
        expect(find.bySemanticsLabel('Senderliste einklappen'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('target actions distinguish pane icons and German direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Row(
            children: [
              M3PaneToggleButton(
                target: M3PaneTarget.categories,
                expanded: false,
                onPressed: () {},
                showLabel: false,
              ),
              M3PaneToggleButton(
                target: M3PaneTarget.channels,
                expanded: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    expect(find.byTooltip('Kategorien anzeigen'), findsOneWidget);
    expect(find.byTooltip('Senderliste einklappen'), findsOneWidget);
    expect(find.text('Kategorien'), findsNothing);
    expect(find.text('Senderliste'), findsOneWidget);
    expect(tester.getSize(find.byType(M3ActionSlot).first), const Size(48, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('target pane actions keep keyboard activation and focus return', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'D13PaneAction');
    addTearDown(focusNode.dispose);
    var activations = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: M3PaneToggleButton(
            target: M3PaneTarget.channels,
            expanded: false,
            focusNode: focusNode,
            onPressed: () => activations++,
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activations, 1);
    expect(focusNode.hasFocus, isTrue);
    expect(find.bySemanticsLabel('Senderliste anzeigen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacked search follows the shared Live header gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          extensions: const <ThemeExtension<dynamic>>[AppSpacing(md: 40)],
        ),
        home: Scaffold(
          body: SizedBox(
            width: 719,
            child: ShellCommandArea(
              title: 'Live TV',
              supportingText: 'Watch live television',
              search: const SizedBox(
                key: ValueKey('d13-search'),
                height: 56,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final supporting = tester.getRect(
      find.byKey(ShellCommandArea.supportingTextKey),
    );
    final search = tester.getRect(find.byKey(ShellCommandArea.searchKey));
    expect(
      search.top,
      closeTo(supporting.bottom + LiveLayoutMetrics.headerTitleSearchGap, 0.01),
    );
    expect(search.height, GlobalSearchField.fieldHeight);
    expect(
      search.bottom,
      LiveHeaderLayoutMetrics.resolve(
        availableWidth: 719,
        textScaleFactor: 1,
      ).height,
    );
    expect(tester.takeException(), isNull);
  });
}
