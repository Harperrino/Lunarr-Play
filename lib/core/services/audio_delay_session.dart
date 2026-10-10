import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';

/// Audio offset belongs to the source being played, not to the app settings.
/// Serializing writes prevents rapid adjustments and source changes racing.
class AudioDelaySession extends ValueNotifier<int> {
  AudioDelaySession({required this.apply}) : super(0);

  static const minimumMs = -60000;
  static const maximumMs = 60000;
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
    final seconds = milliseconds / 1000;
    final saved = _audioDelayBuffers[platform];
    if (milliseconds == 0 && saved == null) {
      await _setCheckedProperty(platform, 'audio-delay', '0');
      return;
    }
    final previous = await platform.getProperty('audio-delay');
    final original = saved ?? await _AudioDelayBufferSettings.read(platform);
    try {
      if (milliseconds != 0) {
        // Live's normal profile disables cache pauses. With separated track
        // timelines this lets the leading track starve while the other keeps
        // playing. Keep a reserve and pause BOTH tracks on an underrun.
        await original.applyForOffset(platform, milliseconds);
      }
      await _setCheckedProperty(platform, 'audio-delay', seconds.toString());
      if (milliseconds == 0 && saved != null) {
        await saved.restore(platform);
      }
      _audioDelayBuffers[platform] = milliseconds == 0 ? null : original;
    } catch (_) {
      // Leave the prior adjustment and its cache policy in place on failure.
      try {
        await platform.setProperty('audio-delay', previous);
        if (saved == null) {
          await original.restore(platform);
        } else {
          final oldMs = ((double.tryParse(previous) ?? 0) * 1000).round();
          await saved.applyForOffset(platform, oldMs);
        }
      } catch (_) {
        // A disposed player cannot be restored; preserve the original error.
      }
      rethrow;
    }
  } else if (platform != null) {
    throw UnsupportedError('Audio delay requires native playback.');
  }
}

final _audioDelayBuffers = Expando<_AudioDelayBufferSettings>();

class _AudioDelayBufferSettings {
  _AudioDelayBufferSettings(this.properties);

  static const _keys = [
    'cache-pause',
    'cache-pause-wait',
    'demuxer-readahead-secs',
    'demuxer-max-bytes',
  ];
  final Map<String, String> properties;

  static Future<_AudioDelayBufferSettings> read(NativePlayer player) async {
    final properties = <String, String>{};
    for (final key in _keys) {
      final value = await player.getProperty(key);
      if (value.isEmpty) {
        throw StateError('The playback engine cannot report $key.');
      }
      properties[key] = value;
    }
    return _AudioDelayBufferSettings(properties);
  }

  Future<void> applyForOffset(NativePlayer player, int milliseconds) async {
    final reserve = (milliseconds.abs() / 1000).ceil() + 5;
    final originalSeconds = double.parse(properties['demuxer-readahead-secs']!);
    final seconds = originalSeconds > reserve ? originalSeconds : reserve;
    final originalBytes = int.parse(properties['demuxer-max-bytes']!);
    final neededBytes = PlayerBufferService.bufferSizeBytesForSeconds(
      seconds.ceil(),
    );
    await _setCheckedProperty(
      player,
      'demuxer-max-bytes',
      '${originalBytes > neededBytes ? originalBytes : neededBytes}',
    );
    await _setCheckedProperty(player, 'demuxer-readahead-secs', '$seconds');
    await _setCheckedProperty(player, 'cache-pause-wait', '1');
    await _setCheckedProperty(player, 'cache-pause', 'yes');
  }

  Future<void> restore(NativePlayer player) async {
    for (final entry in properties.entries) {
      await _setCheckedProperty(player, entry.key, entry.value);
    }
  }
}

Future<void> _setCheckedProperty(
  NativePlayer player,
  String property,
  String value,
) async {
  await player.setProperty(property, value);
  // media_kit ignores mpv's return code, so verify every required setting.
  final actual = await player.getProperty(property);
  final expectedNumber = double.tryParse(value);
  final actualNumber = double.tryParse(actual);
  final matches = expectedNumber == null
      ? actual == value
      : actualNumber != null &&
            actualNumber.isFinite &&
            (actualNumber - expectedNumber).abs() <= 0.0005;
  if (!matches) {
    throw StateError('The playback engine did not apply $property.');
  }
}
