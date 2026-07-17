import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_form.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_screen.dart';

class _InactiveIds extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

class _DebugMode extends DebugModeNotifier {
  @override
  Future<bool> build() async => false;
}

class _PlaylistSync extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _EpgSync extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

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

class _BufferSeconds extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

class _VodBufferSeconds extends VodPreBufferTargetSecondsNotifier {
  @override
  Future<int> build() async => VodPreBufferTargetSecondsNotifier.defaultSeconds;
}

class _ForceStereo extends ForceStereoEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

class _AudioLanguage extends PreferredAudioLanguageNotifier {
  @override
  Future<String?> build() async => null;
}

void main() {
  testWidgets('adding an EPG URL through playlist edit closes cleanly', (
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
      createdAt: DateTime(2026, 7, 17),
    );
    final container = ProviderContainer(
      overrides: [
        playlistsStreamProvider.overrideWith((ref) => Stream.value([playlist])),
        inactivePlaylistIdsProvider.overrideWith(_InactiveIds.new),
        debugModeProvider.overrideWith(_DebugMode.new),
        playlistSyncNotifierProvider.overrideWith(_PlaylistSync.new),
        epgSyncNotifierProvider.overrideWith(_EpgSync.new),
        playlistFormNotifierProvider.overrideWith(_PlaylistForm.new),
        playerBufferSecondsProvider.overrideWith(_BufferSeconds.new),
        vodPreBufferTargetSecondsProvider.overrideWith(_VodBufferSeconds.new),
        forceStereoEnabledProvider.overrideWith(_ForceStereo.new),
        preferredAudioLanguageProvider.overrideWith(_AudioLanguage.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('More playlist actions'),
      250,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('settings-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byTooltip('More playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More playlist actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit playlist'));
    await tester.pumpAndSettle();

    expect(find.text('Edit XTREAM playlist'), findsOneWidget);
    final epgField = find.descendant(
      of: find.ancestor(
        of: find.text('EPG URL (OPTIONAL)'),
        matching: find.byType(SettingsTextField),
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(epgField, 'https://example.invalid/guide.xml');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Edit XTREAM playlist'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
