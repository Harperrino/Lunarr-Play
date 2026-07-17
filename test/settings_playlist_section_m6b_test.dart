import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_section.dart';

void main() {
  testWidgets('narrow playlist actions retain their bound callbacks', (
    tester,
  ) async {
    var syncCount = 0;
    var epgSyncCount = 0;
    var editCount = 0;
    var activeValue = true;
    var deleteCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 640,
            child: SettingsPlaylistSection(
              items: [
                SettingsPlaylistItem(
                  name: 'Example playlist with a deliberately long name',
                  type: 'xtream',
                  isActive: true,
                  lastSyncedAt: DateTime(2026, 7, 12),
                  epgUrl: 'https://example.invalid/guide.xml',
                  epgLastSyncedAt: DateTime(2026, 7, 12),
                  onSync: () => syncCount++,
                  onEpgSync: () => epgSyncCount++,
                  onEdit: () => editCount++,
                  onActiveChanged: (value) => activeValue = value,
                  onDelete: () => deleteCount++,
                ),
              ],
              isLoading: false,
              errorMessage: null,
              isSyncing: false,
              isEpgSyncing: false,
              isBusy: false,
              compact: false,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Sync'));
    await tester.pump();
    expect(syncCount, 1);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(activeValue, isFalse);

    await tester.tap(find.byTooltip('More playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<void>).first);
    await tester.pump();
    expect(editCount, 1);

    await tester.tap(find.byTooltip('More playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<void>).at(1));
    await tester.pump();
    expect(epgSyncCount, 1);

    await tester.tap(find.byTooltip('More playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuItem<void>).at(2));
    await tester.pump();
    expect(deleteCount, 1);
    expect(tester.takeException(), isNull);
  });
}
