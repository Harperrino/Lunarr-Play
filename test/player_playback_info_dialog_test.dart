import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/database/app_database.dart';
import 'package:m3uxtream_player/features/player/models/playback_media_info.dart';
import 'package:m3uxtream_player/features/player/providers/player_providers.dart';
import 'package:m3uxtream_player/features/player/widgets/player_playback_info_dialog.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'audio track exposure label distinguishes raw and selectable states',
    () {
      expect(
        audioTrackExposureStatusLabel(0, 0),
        'No raw audio tracks detected',
      );
      expect(
        audioTrackExposureStatusLabel(2, 0),
        'Audio tracks detected, none currently selectable',
      );
      expect(audioTrackExposureStatusLabel(2, 2), '2 raw / 2 selectable');
    },
  );

  test(
    'audio track display label distinguishes exposed and filtered states',
    () {
      expect(
        audioTrackDisplayLabel(
          currentTrackId: media_kit.AudioTrack.auto().id,
          rawCount: 0,
          selectableCount: 0,
        ),
        'Audio track not exposed by stream/demuxer',
      );

      expect(
        audioTrackDisplayLabel(
          currentTrackId: media_kit.AudioTrack.auto().id,
          rawCount: 2,
          selectableCount: 0,
        ),
        'Audio tracks detected, none currently selectable',
      );

      expect(
        audioTrackDisplayLabel(
          currentTrackId: media_kit.AudioTrack.auto().id,
          rawCount: 2,
          selectableCount: 2,
        ),
        'Auto',
      );

      expect(
        audioTrackDisplayLabel(
          currentTrackId: media_kit.AudioTrack.no().id,
          rawCount: 2,
          selectableCount: 2,
        ),
        'Keine',
      );
    },
  );

  test('decoded audio compatibility hint flags decoded multichannel audio', () {
    expect(
      decodedAudioCompatibilityHint(
        const PlaybackMediaInfo(
          audioFormat: 'floatp',
          audioChannelCount: 6,
          audioChannelsLabel: '5.1(side)',
        ),
      ),
      contains('Stereo erzwingen'),
    );

    expect(
      decodedAudioCompatibilityHint(
        const PlaybackMediaInfo(
          audioFormat: 'floatp',
          audioChannelCount: 2,
          audioChannelsLabel: 'stereo',
        ),
      ),
      isNull,
    );

    expect(decodedAudioCompatibilityHint(PlaybackMediaInfo.empty), isNull);
  });

  testWidgets('dialog stays scrollable in a compact viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = _FakePlayer();

    const channel = Channel(
      id: 1,
      playlistId: 1,
      name: 'Live Channel',
      streamUrl: 'https://example.com/live.m3u8',
      isFavorite: false,
      isWatchLater: false,
      channelType: 'live',
    );

    final state = PlayerState(
      player: player,
      isPlaying: false,
      volume: 0.5,
      isBuffering: false,
      isLiveStartupBuffering: false,
      playbackUri: 'https://example.com/live.m3u8',
      mediaInfo: const PlaybackMediaInfo(
        audioFormat: 'eac3',
        audioBitrateKbps: 768,
        audioChannelCount: 6,
        audioChannelsLabel: '3F2M/LFE',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.highContrastDarkTheme,
        home: Scaffold(
          body: _DialogHost(playerState: state, channel: channel),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    expect(find.text('Wiedergabe-Informationen'), findsOneWidget);
    expect(find.textContaining('Audio-Track-Status'), findsOneWidget);
    expect(find.textContaining('Audio dekodiert'), findsOneWidget);
    expect(find.textContaining('Stereo erzwingen'), findsOneWidget);

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    expect(
      tester.widget<AppSurface>(find.byType(AppSurface)).level,
      AppSurfaceLevel.high,
    );
    expect(
      tester.widget<Text>(find.text('Titel')).style?.color,
      colors.onSurfaceVariant,
    );
    expect(
      tester.widget<Divider>(find.byType(Divider).first).color,
      colors.outlineVariant,
    );
  });
}

class _FakePlayer extends Fake implements media_kit.Player {
  @override
  media_kit.PlayerState get state => media_kit.PlayerState(
    track: media_kit.Track(audio: media_kit.AudioTrack.auto()),
    tracks: media_kit.Tracks(
      audio: [media_kit.AudioTrack.auto(), media_kit.AudioTrack.no()],
    ),
  );
}

class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.playerState, required this.channel});

  final PlayerState playerState;
  final Channel? channel;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  bool _dialogScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dialogScheduled) return;
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showPlayerPlaybackInfoDialog(
        context,
        playerState: widget.playerState,
        channel: widget.channel,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
