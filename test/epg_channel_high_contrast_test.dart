import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/channels/widgets/channel_list_panel.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_program_cell.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  testWidgets('EPG empty state uses high-contrast neutral roles', (
    tester,
  ) async {
    await _pumpEpgEmpty(tester);

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(
      tester.widget<Icon>(find.byIcon(Icons.playlist_play_rounded)).color,
      colors.outline,
    );
    expect(
      tester
          .widget<Text>(
            find.text(
              'Select a playlist and sync channels on the Live tab or in Settings.',
            ),
          )
          .style
          ?.color,
      colors.onSurfaceVariant,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('EPG programme text uses high-contrast content roles', (
    tester,
  ) async {
    final entry = EpgEntry(
      id: 1,
      channelId: 'example.channel',
      title: 'Prime Time',
      description: null,
      startTime: DateTime(2026, 7, 14, 10),
      endTime: DateTime(2026, 7, 14, 11),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.highContrastDarkTheme,
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 80,
            child: Stack(
              children: [
                EpgProgramCell(
                  entry: entry,
                  windowStart: DateTime(2026, 7, 14, 9),
                  windowEnd: DateTime(2026, 7, 14, 12),
                  pixelsPerMinute: 2,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(
      tester.widget<Text>(find.text('Prime Time')).style?.color,
      colors.onSurface,
    );
    expect(
      tester.widget<Text>(find.text('60 min')).style?.color,
      colors.onSurfaceVariant,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('channel empty state uses high-contrast neutral roles', (
    tester,
  ) async {
    await _pumpChannel(tester, channels: Stream.value(const <Channel>[]));

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(find.text('No playlist selected'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.text('Add and sync a playlist to see channels here.'),
          )
          .style
          ?.color,
      colors.onSurfaceVariant,
    );
    final icons = tester.widgetList<Icon>(
      find.byIcon(Icons.playlist_play_rounded),
    );
    expect(icons.last.color, colors.outline);
    expect(tester.takeException(), isNull);
  });

  testWidgets('channel loading shimmer uses high-contrast surface roles', (
    tester,
  ) async {
    final channels = StreamController<List<Channel>>();
    addTearDown(channels.close);
    await _pumpChannel(tester, channels: channels.stream);

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
    final gradient = shimmer.gradient as LinearGradient;
    expect(gradient.colors.first, colors.surfaceContainerLow);
    expect(gradient.colors[2], colors.surfaceContainerHighest);

    final tileFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.minHeight == 52 &&
          widget.constraints?.maxHeight == 52 &&
          widget.decoration is BoxDecoration,
    );
    expect(tileFinder, findsNWidgets(8));
    final tile = tester.widget<Container>(tileFinder.first);
    expect((tile.decoration! as BoxDecoration).color, colors.surfaceContainer);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpEpgEmpty(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError('EPG HC test must not open the database'),
        ),
        epgSyncNotifierProvider.overrideWith(_ReadyEpgSyncNotifier.new),
        epgGridEntriesStreamProvider.overrideWith(
          (ref) => Stream.value(const <EpgEntry>[]),
        ),
        knownEpgChannelIdsProvider.overrideWith(
          (ref) => Stream.value(const <String>{}),
        ),
        epgGridRowsProvider.overrideWith((ref) => const <EpgGridRowData>[]),
        epgGridChannelsProvider.overrideWith((ref) => const <Channel>[]),
        liveChannelsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Channel>[]),
        ),
        playlistsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Playlist>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.highContrastDarkTheme,
        home: const Scaffold(body: EpgScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpChannel(
  WidgetTester tester, {
  required Stream<List<Channel>> channels,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith(
          (ref) =>
              throw StateError('Channel HC test must not open the database'),
        ),
        selectedPlaylistIdProvider.overrideWith((ref) => null),
        playlistsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Playlist>[]),
        ),
        liveChannelsStreamProvider.overrideWith((ref) => channels),
        hiddenGroupsProvider.overrideWith(_EmptyHiddenGroupsNotifier.new),
        inactivePlaylistIdsProvider.overrideWith(
          _EmptyInactivePlaylistIdsNotifier.new,
        ),
        playlistSyncNotifierProvider.overrideWith(
          _ReadyPlaylistSyncNotifier.new,
        ),
        epgSyncNotifierProvider.overrideWith(_ReadyEpgSyncNotifier.new),
        channelFavoriteControllerProvider.overrideWith(
          (ref) => ChannelFavoriteController((channelId) async => true),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.highContrastDarkTheme,
        home: const Scaffold(
          body: SizedBox(width: 700, height: 600, child: ChannelListPanel()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _ReadyEpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

class _ReadyPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _EmptyHiddenGroupsNotifier extends HiddenGroupsNotifier {
  @override
  Future<Set<String>> build() async => const <String>{};
}

class _EmptyInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}
