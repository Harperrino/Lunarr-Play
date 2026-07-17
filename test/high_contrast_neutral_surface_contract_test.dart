import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState, Playlist;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/core/models/streaming_diagnostics.dart';
import 'package:m3uxtream_player/features/channels/providers/channel_providers.dart';
import 'package:m3uxtream_player/features/diagnostics/providers/streaming_diagnostics_providers.dart';
import 'package:m3uxtream_player/features/diagnostics/widgets/streaming_diagnostics_card.dart';
import 'package:m3uxtream_player/features/diagnostics/widgets/ui_log_console_card.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/group_visibility_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/pinned_groups_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_activity_providers.dart';
import 'package:m3uxtream_player/features/playlists/providers/playlist_providers.dart';
import 'package:m3uxtream_player/features/playlists/widgets/playlist_hub_screen.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

import 'support/fake_media_player.dart';

void main() {
  testWidgets(
    'PlaylistHub neutral text follows normal and high-contrast roles',
    (tester) async {
      final container = _playlistContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _themeHost(
          highContrast: false,
          child: UncontrolledProviderScope(
            container: container,
            child: const SizedBox(
              width: 1000,
              height: 700,
              child: PlaylistHubScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final normalColors = AppTheme.darkTheme.colorScheme;
      final normalMessage = tester.widget<Text>(
        find.text('Sync the playlist to load categories.'),
      );
      expect(normalMessage.style?.color, normalColors.onSurfaceVariant);

      await tester.pumpWidget(
        _themeHost(
          highContrast: true,
          child: UncontrolledProviderScope(
            container: container,
            child: const SizedBox(
              width: 1000,
              height: 700,
              child: PlaylistHubScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
      final highContrastMessage = tester.widget<Text>(
        find.text('Sync the playlist to load categories.'),
      );
      expect(
        highContrastMessage.style?.color,
        highContrastColors.onSurfaceVariant,
      );
      expect(
        normalColors.onSurfaceVariant,
        isNot(highContrastColors.onSurfaceVariant),
      );
    },
  );

  testWidgets('diagnostic log surface follows normal and high-contrast roles', (
    tester,
  ) async {
    Future<void> pump(bool highContrast) async {
      await tester.pumpWidget(
        _themeHost(
          highContrast: highContrast,
          child: SizedBox(
            width: 700,
            height: 420,
            child: UiLogConsoleCard(
              logs: const ['Example diagnostic entry'],
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(false);
    final normalColors = AppTheme.darkTheme.colorScheme;
    _expectLogRoles(tester, normalColors);

    await pump(true);
    final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
    _expectLogRoles(tester, highContrastColors);
    expect(normalColors.onSurface, isNot(highContrastColors.onSurface));
  });

  testWidgets(
    'StreamingDiagnosticsCard uses high-contrast neutral foregrounds',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('High-contrast contract opened database'),
          ),
          playerNotifierProvider.overrideWith(_TestPlayerNotifier.new),
          streamingDiagnosticsSettingsProvider.overrideWith(
            _TestStreamingDiagnosticsSettingsNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _themeHost(
          highContrast: true,
          child: UncontrolledProviderScope(
            container: container,
            child: const SizedBox(
              width: 900,
              height: 700,
              child: StreamingDiagnosticsCard(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final colors = AppTheme.highContrastDarkTheme.colorScheme;
      _expectTonalSurface(tester, colors);
      expect(
        tester.widget<Text>(find.text('Erweiterte Diagnose')).style?.color,
        colors.onSurfaceVariant,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Letzten Fehler kopieren'),
        findsOneWidget,
      );
    },
  );
}

Widget _themeHost({required bool highContrast, required Widget child}) {
  final theme = highContrast
      ? AppTheme.highContrastDarkTheme
      : AppTheme.darkTheme;
  return MaterialApp(
    key: ValueKey<bool>(highContrast),
    theme: theme,
    home: Scaffold(body: child),
  );
}

ProviderContainer _playlistContainer() {
  return ProviderContainer(
    overrides: [
      playlistsStreamProvider.overrideWith(
        (ref) => Stream.value(<Playlist>[_playlist]),
      ),
      channelsStreamProvider.overrideWith(
        (ref) => Stream.value(const <Channel>[]),
      ),
      inactivePlaylistIdsProvider.overrideWith(
        _EmptyInactivePlaylistIdsNotifier.new,
      ),
      hiddenGroupsProvider.overrideWith(_EmptyHiddenGroupsNotifier.new),
      pinnedGroupsProvider.overrideWith(_EmptyPinnedGroupsNotifier.new),
    ],
  );
}

void _expectLogRoles(WidgetTester tester, ColorScheme colors) {
  final surfaces = tester.widgetList<AppSurface>(find.byType(AppSurface));
  expect(
    surfaces.where((surface) => surface.level == AppSurfaceLevel.high),
    hasLength(1),
  );
  expect(
    surfaces.where((surface) => surface.level == AppSurfaceLevel.base),
    hasLength(1),
  );
  final materials = tester.widgetList<Material>(
    find.descendant(
      of: find.byType(AppSurface),
      matching: find.byType(Material),
    ),
  );
  expect(
    materials.any((material) => material.color == colors.surfaceContainerHigh),
    isTrue,
  );
  expect(materials.any((material) => material.color == colors.surface), isTrue);
  expect(
    tester.widget<Text>(find.text('Example diagnostic entry')).style?.color,
    colors.onSurface,
  );
  expect(
    tester
        .widget<Text>(
          find.text(
            'Press [Space] for Play/Pause, [F] for Fullscreen, [+/-] for Volume, [Arrow keys] to change channel.',
          ),
        )
        .style
        ?.color,
    colors.onSurfaceVariant,
  );
}

void _expectTonalSurface(WidgetTester tester, ColorScheme colors) {
  final surfaces = tester.widgetList<AppSurface>(find.byType(AppSurface));
  expect(
    surfaces.where((surface) => surface.level == AppSurfaceLevel.high),
    hasLength(1),
  );
  expect(
    surfaces.where((surface) => surface.level == AppSurfaceLevel.low),
    hasLength(3),
  );
  final materials = tester.widgetList<Material>(
    find.descendant(
      of: find.byType(AppSurface),
      matching: find.byType(Material),
    ),
  );
  expect(
    materials.any((material) => material.color == colors.surfaceContainerHigh),
    isTrue,
  );
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

class _TestStreamingDiagnosticsSettingsNotifier
    extends StreamingDiagnosticsSettingsNotifier {
  @override
  Future<StreamingDiagnosticsSettings> build() async {
    return const StreamingDiagnosticsSettings(
      autoFallbackEnabled: false,
      showOnErrorEnabled: false,
    );
  }
}

class _TestPlayerNotifier extends PlayerNotifier {
  @override
  Future<PlayerState> build() async => PlayerState(
    player: FakeMediaPlayer(),
    playbackUri: null,
    isPlaying: false,
    volume: 0.5,
    isBuffering: false,
    isLiveStartupBuffering: false,
  );

  @override
  VideoController videoControllerFor(Player player) => VideoController(player);
}

final _playlist = Playlist(
  id: 1,
  name: 'Test playlist',
  type: 'm3u',
  urlOrHost: 'https://example.invalid/list.m3u',
  createdAt: DateTime(2026, 7, 1),
);
