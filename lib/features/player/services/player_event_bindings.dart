import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// Owns the media_kit stream subscriptions for one [Player] instance.
///
/// The callbacks deliberately stay with the notifier: this class only makes
/// subscription setup and teardown one explicit lifecycle boundary.
class PlayerEventBindings {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool get isBound => _subscriptions.isNotEmpty;

  void bind(
    Player player, {
    required void Function(bool value) onPlaying,
    required void Function(double value) onVolume,
    required void Function(bool value) onBuffering,
    required void Function(String value) onError,
    required void Function(Duration value) onPosition,
    required void Function(Duration value) onDuration,
    required void Function(Duration value) onBuffer,
    required void Function(Tracks value) onTracks,
    required void Function(dynamic value) onVideoParams,
    required void Function(dynamic value) onAudioParams,
    required void Function(double? value) onAudioBitrate,
  }) {
    if (isBound) {
      throw StateError('PlayerEventBindings is already bound.');
    }

    _subscriptions.addAll([
      player.stream.playing.listen(onPlaying),
      player.stream.volume.listen(onVolume),
      player.stream.buffering.listen(onBuffering),
      player.stream.error.listen(onError),
      player.stream.position.listen(onPosition),
      player.stream.duration.listen(onDuration),
      player.stream.buffer.listen(onBuffer),
      player.stream.tracks.listen(onTracks),
      player.stream.videoParams.listen(onVideoParams),
      player.stream.audioParams.listen(onAudioParams),
      player.stream.audioBitrate.listen(onAudioBitrate),
    ]);
  }

  Future<void> dispose() async {
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait<void>(
      subscriptions.map((subscription) => subscription.cancel()),
    );
  }
}
