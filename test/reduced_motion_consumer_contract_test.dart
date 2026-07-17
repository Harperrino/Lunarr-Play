import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/vod_pre_buffer_settings_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_form.dart';
import 'package:m3uxtream_player/features/xtream/providers/playback_prep_providers.dart';
import 'package:m3uxtream_player/features/xtream/widgets/playback_prep_panel.dart';
import 'package:m3uxtream_player/shared/theme/app_motion.dart';
import 'package:m3uxtream_player/shared/widgets/category_sidebar.dart';

const _motion = AppMotion(
  state: Duration(milliseconds: 40),
  content: Duration(milliseconds: 180),
  rail: Duration(milliseconds: 240),
  reduced: Duration.zero,
  standardCurve: Curves.linear,
  emphasizedCurve: Curves.easeIn,
);

void main() {
  testWidgets(
    'CategorySidebar resolves content motion for normal and reduced states',
    (tester) async {
      await _pumpMotion(
        tester,
        reduced: false,
        child: const SizedBox(
          width: 240,
          height: 360,
          child: CategorySidebar(
            groups: ['News'],
            selectedGroup: 'All',
            onSelected: _ignoreGroup,
          ),
        ),
      );
      _expectDurations(tester, _motion.content);

      await _pumpMotion(
        tester,
        reduced: true,
        child: const SizedBox(
          width: 240,
          height: 360,
          child: CategorySidebar(
            groups: ['News'],
            selectedGroup: 'All',
            onSelected: _ignoreGroup,
          ),
        ),
      );
      _expectDurations(tester, Duration.zero);
    },
  );

  testWidgets('Settings playlist mode selector resolves reduced motion', (
    tester,
  ) async {
    final controllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    Widget form() => SettingsPlaylistForm(
      mode: SettingsPlaylistFormMode.m3u,
      nameController: controllers[0],
      urlController: controllers[1],
      hostController: controllers[2],
      usernameController: controllers[3],
      passwordController: controllers[4],
      epgUrlController: controllers[5],
      isBusy: false,
      compact: true,
      onModeChanged: (_) {},
      onSubmit: _noop,
    );

    await _pumpMotion(
      tester,
      reduced: false,
      child: SizedBox(width: 520, height: 700, child: form()),
    );
    _expectSegmentedModeControl(tester);

    await _pumpMotion(
      tester,
      reduced: true,
      child: SizedBox(width: 520, height: 700, child: form()),
    );
    _expectSegmentedModeControl(tester);
  });

  testWidgets('PlaybackPrepPanel action surfaces use built-in state layers', (
    tester,
  ) async {
    final target = PlaybackPrepTarget(
      playbackChannel: _channel,
      streamUrl: _channel.streamUrl,
    );

    Widget panel({required bool reduced}) => ProviderScope(
      overrides: [
        playbackPrepControllerProvider.overrideWith(
          _IdlePlaybackPrepController.new,
        ),
        vodPreBufferEnabledProvider.overrideWith(
          _ReadyPreBufferEnabledNotifier.new,
        ),
        vodPreBufferTargetSecondsProvider.overrideWith(
          _ReadyPreBufferTargetNotifier.new,
        ),
        playbackPrepBufferProgressProvider.overrideWith((ref) => 0.0),
        playbackPrepMediaInfoProvider.overrideWith(
          (ref) => PlaybackMediaInfo.empty,
        ),
      ],
      child: _motionHost(
        reduced: reduced,
        child: SizedBox(
          width: 900,
          height: 700,
          child: PlaybackPrepPanel(target: target),
        ),
      ),
    );

    await tester.pumpWidget(panel(reduced: false));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(panel(reduced: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMotion(
  WidgetTester tester, {
  required bool reduced,
  required Widget child,
}) async {
  await tester.pumpWidget(_motionHost(reduced: reduced, child: child));
  await tester.pump();
}

Widget _motionHost({required bool reduced, required Widget child}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[_motion],
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: child),
    ),
  );
}

void _expectDurations(WidgetTester tester, Duration expected) {
  final containers = tester
      .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
      .toList();
  expect(containers, isNotEmpty);
  expect(
    containers.every((container) => container.duration == expected),
    isTrue,
  );
  expect(tester.takeException(), isNull);
}

void _expectSegmentedModeControl(WidgetTester tester) {
  expect(
    find.byWidgetPredicate((widget) => widget is SegmentedButton),
    findsOneWidget,
  );
  expect(find.byType(AnimatedContainer), findsNothing);
  expect(tester.takeException(), isNull);
}

class _IdlePlaybackPrepController extends PlaybackPrepController {
  @override
  PlaybackPrepState build() => const PlaybackPrepState();
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

void _noop() {}

void _ignoreGroup(String _) {}
