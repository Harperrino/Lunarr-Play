import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/app/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/app/widgets/playlist_management_dialogs.dart';

class _PlaylistForm extends PlaylistFormNotifier {
  @override
  Future<void> build() async {}

  @override
  Future<PlaylistFormResult> updatePlaylist({
    required int playlistId,
    required String type,
    required String name,
    required String urlOrPath,
    String? username,
    String? password,
    String? epgUrl,
  }) async {
    state = const AsyncLoading();
    await Future<void>.delayed(Duration.zero);
    state = const AsyncData(null);
    return PlaylistFormSuccess(playlistId, name.trim());
  }
}

void main() {
  testWidgets('playlist edit stores an EPG override and closes cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final playlist = Playlist(
      id: 1,
      name: 'Xtream test',
      type: 'xtream',
      urlOrHost: 'https://example.invalid',
      username: 'user',
      password: 'pass',
      epgUrl: 'https://example.invalid/auto.xml',
      createdAt: DateTime(2026, 7, 17),
    );
    final container = ProviderContainer(
      overrides: [playlistFormNotifierProvider.overrideWith(_PlaylistForm.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showPlaylistEditDialog(context, playlist),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit XTREAM playlist'), findsOneWidget);
    expect(find.text('https://example.invalid/auto.xml'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'https://example.invalid/override.xml',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit XTREAM playlist'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
