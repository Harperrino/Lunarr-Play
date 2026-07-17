import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';
import 'package:m3uxtream_player/app/shell/standard_app_shell.dart';
import 'package:m3uxtream_player/features/epg/providers/epg_sync_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_sync_providers.dart';
import 'package:m3uxtream_player/features/player/providers/player_settings_providers.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/debug_mode_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/playlist_form_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_screen.dart';

class _TestPlayerBufferSecondsNotifier extends PlayerBufferSecondsNotifier {
  @override
  Future<int> build() async => 0;
}

class _TestVodPreBufferNotifier extends VodPreBufferTargetSecondsNotifier {
  @override
  Future<int> build() async => VodPreBufferTargetSecondsNotifier.defaultSeconds;
}

class _TestForceStereoNotifier extends ForceStereoEnabledNotifier {
  @override
  Future<bool> build() async => false;
}

class _TestPreferredAudioLanguageNotifier
    extends PreferredAudioLanguageNotifier {
  @override
  Future<String?> build() async => null;
}

class _TestInactivePlaylistIdsNotifier extends InactivePlaylistIdsNotifier {
  @override
  Future<Set<int>> build() async => const <int>{};
}

class _TestDebugModeNotifier extends DebugModeNotifier {
  @override
  Future<bool> build() async => false;
}

class _TestPlaylistSyncNotifier extends PlaylistSyncNotifier {
  @override
  Future<void> build() async {}
}

class _TestEpgSyncNotifier extends EpgSyncNotifier {
  @override
  Future<void> build() async {}
}

class _TestPlaylistFormNotifier extends PlaylistFormNotifier {
  @override
  Future<void> build() async {}
}

List<Override> _settingsOverrides() => [
  playlistsStreamProvider.overrideWith(
    (ref) => Stream.value(const <Playlist>[]),
  ),
  inactivePlaylistIdsProvider.overrideWith(
    _TestInactivePlaylistIdsNotifier.new,
  ),
  playlistFormNotifierProvider.overrideWith(_TestPlaylistFormNotifier.new),
  playlistSyncNotifierProvider.overrideWith(_TestPlaylistSyncNotifier.new),
  epgSyncNotifierProvider.overrideWith(_TestEpgSyncNotifier.new),
  debugModeProvider.overrideWith(_TestDebugModeNotifier.new),
  playerBufferSecondsProvider.overrideWith(
    _TestPlayerBufferSecondsNotifier.new,
  ),
  vodPreBufferTargetSecondsProvider.overrideWith(_TestVodPreBufferNotifier.new),
  forceStereoEnabledProvider.overrideWith(_TestForceStereoNotifier.new),
  preferredAudioLanguageProvider.overrideWith(
    _TestPreferredAudioLanguageNotifier.new,
  ),
];

Widget _host({
  required double width,
  required bool expanded,
  int activeIndex = shellLiveTabIndex,
}) {
  return ProviderScope(
    overrides: _settingsOverrides(),
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 720,
          child: StandardAppShell(
            activeIndex: activeIndex,
            debugModeEnabled: false,
            sidebarExpanded: expanded,
            onSidebarToggle: () {},
            onSidebarTap: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final testCase in const [
    (width: 231.0, expanded: true),
    (width: 232.0, expanded: true),
    (width: 55.0, expanded: true),
    (width: 1.0, expanded: true),
    (width: 75.0, expanded: false),
    (width: 76.0, expanded: false),
    (width: 1.0, expanded: false),
  ]) {
    testWidgets('shell has no layout exception at ${testCase.width} px', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(width: testCase.width, expanded: testCase.expanded),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid active index follows the shell settings fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(width: 1200, expanded: true, activeIndex: 99),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Feature — Coming Soon'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
