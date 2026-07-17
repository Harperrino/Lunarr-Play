import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/playback_prep_panel.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

void main() {
  testWidgets(
    'PlaybackPrepPanel neutral foregrounds follow normal and high contrast roles',
    (tester) async {
      await _pumpPanel(tester, highContrast: false);
      _expectPanelRoles(tester, AppTheme.darkTheme.colorScheme);

      await _pumpPanel(tester, highContrast: true);
      final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
      _expectPanelRoles(tester, highContrastColors);
      expect(
        AppTheme.darkTheme.colorScheme.onSurfaceVariant,
        isNot(highContrastColors.onSurfaceVariant),
      );
      expect(
        AppTheme.darkTheme.colorScheme.outline,
        isNot(highContrastColors.outline),
      );
    },
  );

  testWidgets(
    'PlaybackPrepPanel loading track follows high-contrast surface role',
    (tester) async {
      await _pumpPanel(
        tester,
        highContrast: true,
        controller: _PreparingPlaybackPrepController.new,
        progress: 0.5,
      );

      final colors = AppTheme.highContrastDarkTheme.colorScheme;
      final track = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(track.backgroundColor, colors.surfaceContainerLow);
      expect(
        tester.widget<Text>(find.text('Puffert... 50 %')).style?.color,
        colors.onSurfaceVariant,
      );
    },
  );
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required bool highContrast,
  PlaybackPrepController Function()? controller,
  double progress = 0,
}) async {
  final theme = highContrast
      ? AppTheme.highContrastDarkTheme
      : AppTheme.darkTheme;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError('PlaybackPrep HC contract opened database'),
        ),
        playbackPrepControllerProvider.overrideWith(
          controller ?? _IdlePlaybackPrepController.new,
        ),
        vodPreBufferEnabledProvider.overrideWith(
          _ReadyPreBufferEnabledNotifier.new,
        ),
        vodPreBufferTargetSecondsProvider.overrideWith(
          _ReadyPreBufferTargetNotifier.new,
        ),
        playbackPrepBufferProgressProvider.overrideWith((ref) => progress),
        playbackPrepMediaInfoProvider.overrideWith(
          (ref) => PlaybackMediaInfo.empty,
        ),
      ],
      child: MaterialApp(
        key: ValueKey<bool>(highContrast),
        theme: theme,
        home: Scaffold(
          body: const SizedBox(
            width: 900,
            height: 700,
            child: PlaybackPrepPanel(
              target: PlaybackPrepTarget(
                playbackChannel: _channel,
                streamUrl: 'https://example.invalid/movie.m3u8',
                subtitle: 'Contract subtitle',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _expectPanelRoles(WidgetTester tester, ColorScheme colors) {
  expect(find.byType(AppSurface), findsNWidgets(4));

  final headerSubtitle = tester.widget<Text>(
    find.text('Pre-buffered start for smoother scrubbing and faster resume.'),
  );
  expect(headerSubtitle.style?.color, colors.onSurfaceVariant);

  final detailSubtitles = tester.widgetList<Text>(
    find.text('Vor dem Abspielen puffern - verbessert Vor- und Zuruckspulen.'),
  );
  expect(detailSubtitles, isNotEmpty);
  expect(
    detailSubtitles.every(
      (text) => text.style?.color == colors.onSurfaceVariant,
    ),
    isTrue,
  );

  expect(
    tester.widget<Text>(find.text('Contract subtitle')).style?.color,
    colors.onSurfaceVariant,
  );
  expect(
    tester.widget<Text>(find.text('Movies')).style?.color,
    colors.onSurfaceVariant,
  );
  expect(find.text('Direkt starten'), findsOneWidget);
  expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
  expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  expect(find.byType(FilledButton), findsNWidgets(2));
  expect(find.byTooltip('Zuruck'), findsOneWidget);
}

class _IdlePlaybackPrepController extends PlaybackPrepController {
  @override
  PlaybackPrepState build() => const PlaybackPrepState();
}

class _PreparingPlaybackPrepController extends PlaybackPrepController {
  @override
  PlaybackPrepState build() =>
      const PlaybackPrepState(phase: PlaybackPrepPhase.preparing);
}

class _ReadyPreBufferEnabledNotifier extends VodPreBufferEnabledNotifier {
  @override
  Future<bool> build() async => true;
}

class _ReadyPreBufferTargetNotifier extends VodPreBufferTargetSecondsNotifier {
  @override
  Future<int> build() async => VodPreBufferTargetSecondsNotifier.defaultSeconds;
}

const _channel = Channel(
  id: 1,
  playlistId: 1,
  streamId: 'movie-1',
  name: 'Example movie',
  logo: null,
  groupName: 'Movies',
  tvgId: null,
  streamUrl: 'https://example.invalid/movie.m3u8',
  isFavorite: false,
  isWatchLater: false,
  channelType: 'vod',
  lastWatchedPosition: null,
  duration: null,
  lastWatchedAt: null,
);
