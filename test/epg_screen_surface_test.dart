import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_grid_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_providers.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_screen.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_toolbar.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError(
            'EPG screen surface tests must not open the database',
          ),
        ),
        epgSyncNotifierProvider.overrideWith(_TestEpgSyncNotifier.new),
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
    );
    addTearDown(container.dispose);
  });

  testWidgets('EPG keeps its desktop content in a tonal outer surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: EpgScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final surface = find.byKey(const ValueKey('epg-screen-surface'));
    expect(surface, findsOneWidget);
    expect(tester.widget<AppSurface>(surface).level, AppSurfaceLevel.high);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen adapter preserves navigation and zoom contracts', (
    tester,
  ) async {
    final initialStart = container.read(epgWindowStartProvider);
    final initialEnd = container.read(epgWindowEndProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: EpgScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _tapAction(tester, EpgToolbarAction.backTwoHours);
    expect(
      container.read(epgWindowStartProvider),
      initialStart.subtract(const Duration(hours: 2)),
    );
    expect(
      container.read(epgWindowEndProvider),
      initialEnd.subtract(const Duration(hours: 2)),
    );

    await _tapAction(tester, EpgToolbarAction.forwardTwoHours);
    expect(container.read(epgWindowStartProvider), initialStart);
    expect(container.read(epgWindowEndProvider), initialEnd);

    await _tapAction(tester, EpgToolbarAction.backOneDay);
    expect(
      container.read(epgWindowStartProvider),
      initialStart.subtract(const Duration(days: 1)),
    );
    await _tapAction(tester, EpgToolbarAction.forwardOneDay);
    expect(container.read(epgWindowStartProvider), initialStart);

    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteDefault,
    );
    await _tapAction(tester, EpgToolbarAction.zoomOut);
    expect(container.read(epgGridPixelsPerMinuteProvider), 1.75);
    await _tapAction(tester, EpgToolbarAction.zoomIn);
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteDefault,
    );

    container.read(epgGridPixelsPerMinuteProvider.notifier).state =
        epgGridPixelsPerMinuteMin;
    await _tapAction(tester, EpgToolbarAction.zoomOut);
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteMin,
    );
    container.read(epgGridPixelsPerMinuteProvider.notifier).state =
        epgGridPixelsPerMinuteMax;
    await _tapAction(tester, EpgToolbarAction.zoomIn);
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteMax,
    );
    await _tapAction(tester, EpgToolbarAction.resetZoom);
    expect(
      container.read(epgGridPixelsPerMinuteProvider),
      epgGridPixelsPerMinuteDefault,
    );

    final initialTick = container.read(epgGridScrollToNowTickProvider);
    await _tapAction(tester, EpgToolbarAction.now);
    expect(container.read(epgGridScrollToNowTickProvider), initialTick + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state uses semantic subdued ColorScheme roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: EpgScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final colors = AppTheme.darkTheme.colorScheme;
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
}

class _TestEpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

Future<void> _tapAction(WidgetTester tester, EpgToolbarAction action) async {
  await tester.tap(find.byKey(EpgToolbar.actionKey(action)));
  await tester.pump();
}
