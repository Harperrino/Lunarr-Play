import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_player_controller.dart';
import 'package:m3uxtream_player/features/jellyfin/playback/jellyfin_playback_reporter.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_library_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';

/// Host hook that stops an existing Lunarr/Xtream stream before Jellyfin
/// playback starts. The feature default is a no-op; the app composition root
/// overrides it with `JellyfinPlaybackHostBridge`.
final jellyfinExistingPlaybackStopperProvider =
    Provider<JellyfinExistingPlaybackStopper?>((ref) => null);

/// Session reporting stays injectable so playback tests can remain fully
/// deterministic without issuing network calls.
final jellyfinPlaybackReporterProvider = Provider<JellyfinPlaybackReporter>(
  (ref) =>
      JellyfinPlaybackReporter(apiClient: ref.watch(jellyfinApiClientProvider)),
);

/// Feature/screen-scoped Jellyfin player instance.
///
/// `autoDispose` gives the deterministic lifecycle: as soon as the playback
/// screen (or the whole Jellyfin tab) stops listening, the controller stops,
/// disposes its `VideoController` and its `Player` — no background audio.
final jellyfinPlayerControllerProvider =
    AutoDisposeProvider<JellyfinPlayerController>((ref) {
      final session = ref.watch(jellyfinSessionControllerProvider);
      final connection = session is JellyfinAuthenticated
          ? session.connection
          : null;
      if (connection == null) {
        throw StateError('Jellyfin session is not authenticated.');
      }
      final controller = JellyfinPlayerController(
        connection: connection,
        apiClient: ref.watch(jellyfinApiClientProvider),
        stopExistingPlayback: ref.watch(
          jellyfinExistingPlaybackStopperProvider,
        ),
        playbackReporter: ref.watch(jellyfinPlaybackReporterProvider),
        onPlaybackStopped: () => ref.invalidate(jellyfinHomeDataProvider),
      );
      ref.onDispose(() => unawaited(controller.disposeAsync()));
      return controller;
    });
