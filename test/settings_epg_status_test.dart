import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/models/epg_refresh_interval.dart';
import 'package:m3uxtream_player/core/models/epg_sync_job.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_section.dart';

SettingsPlaylistItem _item({EpgSyncJob? job, VoidCallback? onRetry}) {
  return SettingsPlaylistItem(
    name: 'Example playlist',
    type: 'm3u',
    isActive: true,
    lastSyncedAt: DateTime(2026, 7, 20),
    epgUrl: 'https://example.invalid/guide.xml',
    epgLastSyncedAt: null,
    epgRefreshInterval: EpgRefreshInterval.hours6,
    epgSyncJob: job,
    onSync: () {},
    onEpgSync: () {},
    onEdit: () {},
    onActiveChanged: (_) {},
    onDelete: () {},
    onEpgRefreshIntervalChanged: (_) {},
    onEpgRetry: onRetry,
  );
}

Widget _host(SettingsPlaylistItem item) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 640,
        height: 720,
        child: SettingsPlaylistSection(
          items: [item],
          isLoading: false,
          errorMessage: null,
          isSyncing: false,
          isEpgSyncing: false,
          isBusy: false,
          compact: false,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('queued EPG state is inline and disables only that playlist', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 20, 12);
    await tester.pumpWidget(
      _host(
        _item(
          job: EpgSyncJob(
            playlistId: 1,
            status: EpgSyncStatus.queued,
            origin: EpgSyncOrigin.manual,
            requestedAt: now,
          ),
        ),
      ),
    );

    expect(find.text('EPG-Aktualisierung wartet …'), findsOneWidget);
    final dropdown = tester.widget<DropdownButton<EpgRefreshInterval>>(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButton<EpgRefreshInterval>,
      ),
    );
    expect(dropdown.onChanged, isNull);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('failed EPG state offers an inline retry action', (tester) async {
    var retries = 0;
    final now = DateTime(2026, 7, 20, 12);
    await tester.pumpWidget(
      _host(
        _item(
          job: EpgSyncJob(
            playlistId: 1,
            status: EpgSyncStatus.failed,
            origin: EpgSyncOrigin.manual,
            requestedAt: now,
            completedAt: now,
            error: StateError('offline'),
          ),
          onRetry: () => retries++,
        ),
      ),
    );

    expect(
      find.textContaining('EPG-Aktualisierung fehlgeschlagen'),
      findsOneWidget,
    );
    await tester.tap(find.text('Erneut versuchen'));
    expect(retries, 1);
  });
}
