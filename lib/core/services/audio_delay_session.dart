import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Audio offset belongs to the source being played, not to the app settings.
/// Serializing writes prevents rapid adjustments and source changes racing.
class AudioDelaySession extends ValueNotifier<int> {
  AudioDelaySession({required this.apply}) : super(0);

  static const minimumMs = -2000;
  static const maximumMs = 2000;
  static const stepMs = 50;

  final Future<void> Function(int milliseconds) apply;
  Object? _source;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _pending = Future<void>.value();

  Future<void> beginPlayback(Object? source) {
    if (_source != source) {
      _source = source;
      _generation++;
      value = 0;
    }
    return reapply();
  }

  Future<void> setMilliseconds(int milliseconds) =>
      _write(milliseconds.clamp(minimumMs, maximumMs));

  Future<void> reapply() => _write(null);

  Future<void> _write(int? milliseconds) {
    final generation = _generation;
    final operation = _pending.then((_) async {
      if (_disposed || generation != _generation) return;
      final target = milliseconds ?? value;
      await apply(target);
      if (!_disposed && generation == _generation) value = target;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

Future<void> applyNativeAudioDelay(Player player, int milliseconds) async {
  final platform = player.platform;
  if (platform is NativePlayer) {
    await platform.setProperty('audio-delay', (milliseconds / 1000).toString());
  } else if (platform != null) {
    throw UnsupportedError('Audio delay requires native playback.');
  }
}
