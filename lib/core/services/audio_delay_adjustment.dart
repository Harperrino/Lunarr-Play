import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/core/services/player_buffer_service.dart';

enum AudioDelayPhase { idle, buffering, aligning }

class AudioDelayProgress {
  const AudioDelayProgress(
    this.phase, {
    this.bufferedSeconds = 0,
    this.targetSeconds = 0,
  });
  final AudioDelayPhase phase;
  final double bufferedSeconds;
  final double targetSeconds;
}

enum AudioDelayFailure { cancelled, superseded, unavailable, timeout }

class AudioDelayAdjustmentException implements Exception {
  const AudioDelayAdjustmentException(this.failure);
  final AudioDelayFailure failure;
}

class AudioDelayAdjustment {
  const AudioDelayAdjustment({
    required this.isCurrent,
    required this.isCancelled,
    required this.report,
  });
  final bool Function() isCurrent;
  final bool Function() isCancelled;
  final void Function(AudioDelayProgress) report;

  void check() {
    if (!isCurrent()) {
      throw const AudioDelayAdjustmentException(AudioDelayFailure.superseded);
    }
    if (isCancelled()) {
      throw const AudioDelayAdjustmentException(AudioDelayFailure.cancelled);
    }
  }
}

/// Rebuild both decode queues at the held video timestamp instead of allowing
/// mpv to catch up by playing audio alone or skipping visible video frames.
Future<void> alignNativeAudioDelay(
  Player player,
  int milliseconds, {
  required AudioDelayAdjustment adjustment,
  required Future<void> Function(int) applyOffset,
  required bool isLive,
  required int preBufferSeconds,
}) async {
  final native = player.platform;
  if (native is! NativePlayer) {
    adjustment.check();
    await applyOffset(milliseconds);
    return;
  }
  adjustment.check();
  final wasPaused = await native.getProperty('pause') == 'yes';
  final previous =
      ((double.tryParse(await native.getProperty('audio-delay')) ?? 0) * 1000)
          .round();
  final oldPath = await native.getProperty('path');
  await player.pause();
  final held = double.tryParse(await native.getProperty('time-pos'));
  if (held == null || oldPath.isEmpty) {
    if (!wasPaused && adjustment.isCurrent()) await player.play();
    throw const AudioDelayAdjustmentException(AudioDelayFailure.unavailable);
  }
  final seconds = milliseconds / 1000;
  final low = math.min(held, held - seconds);
  final high = math.max(held, held - seconds);
  final reserve = math.max(1, preBufferSeconds).toDouble();
  final deadline = DateTime.now().add(
    Duration(seconds: preBufferSeconds + milliseconds.abs() ~/ 1000 + 30),
  );
  var changed = false;
  final temporaryCache = <String, String>{};

  Future<void> setChecked(String key, String value) async {
    await native.setProperty(key, value);
    final actual = double.tryParse(await native.getProperty(key));
    if (actual == null ||
        !actual.isFinite ||
        (actual - double.parse(value)).abs() > 0.0005) {
      throw StateError('The playback engine did not apply $key.');
    }
  }

  Future<void> checkSource() async {
    adjustment.check();
    if (await native.getProperty('path') != oldPath) {
      throw const AudioDelayAdjustmentException(AudioDelayFailure.superseded);
    }
  }

  Future<void> seekHeld() async {
    // media_kit's seek uses keyframe seeking by default; exact is essential here.
    await native.command(['seek', '$held', 'absolute+exact']);
    do {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await checkSource();
      final position = double.tryParse(await native.getProperty('time-pos'));
      final audio = double.tryParse(await native.getProperty('audio-pts'));
      final seeking = await native.getProperty('seeking') == 'yes';
      if (!seeking &&
          position != null &&
          (position - held).abs() < 0.15 &&
          // audio-pts is an output clock, not the decode queue's timestamp.
          // mpv may clear it on a paused seek until the audio output restarts.
          (audio == null || (audio - (held - seconds)).abs() < 0.4)) {
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const AudioDelayAdjustmentException(AudioDelayFailure.timeout);
      }
    } while (true);
  }

  try {
    await checkSource();
    if (low < -0.05) {
      throw const AudioDelayAdjustmentException(AudioDelayFailure.unavailable);
    }
    if (!isLive) {
      final duration = double.tryParse(await native.getProperty('duration'));
      if (duration != null && duration > 0 && high >= duration) {
        throw const AudioDelayAdjustmentException(
          AudioDelayFailure.unavailable,
        );
      }
    }
    await checkSource();
    await applyOffset(milliseconds);
    changed = true;
    // Keep the user's requested pre-buffer AND the separation between tracks.
    final readAhead = double.parse(
      await native.getProperty('demuxer-readahead-secs'),
    );
    final needed =
        preBufferSeconds +
        milliseconds.abs() / 1000 +
        (milliseconds == 0 ? 1 : 5);
    final oldBytes = int.parse(await native.getProperty('demuxer-max-bytes'));
    final bytes = PlayerBufferService.audioSyncBufferBytes(needed.ceil());
    if (oldBytes < bytes) {
      if (milliseconds == 0) temporaryCache['demuxer-max-bytes'] = '$oldBytes';
      await setChecked('demuxer-max-bytes', '$bytes');
    }
    if (readAhead < needed) {
      if (milliseconds == 0) {
        temporaryCache['demuxer-readahead-secs'] = '$readAhead';
      }
      await setChecked('demuxer-readahead-secs', '$needed');
    }
    if (isLive) {
      do {
        await checkSource();
        final text = await native.getProperty('demuxer-cache-state');
        final cache = text.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(text) as Map<String, dynamic>;
        final ranges = (cache['seekable-ranges'] as List?) ?? const [];
        var ready = false;
        var available = 0.0;
        for (final range in ranges) {
          final start = (range['start'] as num).toDouble();
          final end = (range['end'] as num).toDouble();
          if (start <= low + 0.05) {
            available = math.max(available, math.max(0, end - low));
            if (end >= high + reserve ||
                (cache['eof'] == true && end >= high)) {
              ready = true;
            }
          }
        }
        // Future packets can arrive; already discarded past packets cannot.
        if (ranges.isNotEmpty &&
            ranges.every((range) => (range['start'] as num) > low + 0.05)) {
          throw const AudioDelayAdjustmentException(
            AudioDelayFailure.unavailable,
          );
        }
        adjustment.report(
          AudioDelayProgress(
            AudioDelayPhase.buffering,
            bufferedSeconds: available,
            targetSeconds: high - low + reserve,
          ),
        );
        if (ready) break;
        if (DateTime.now().isAfter(deadline)) {
          throw const AudioDelayAdjustmentException(AudioDelayFailure.timeout);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } while (true);
    }
    await checkSource();
    adjustment.report(const AudioDelayProgress(AudioDelayPhase.aligning));
    await seekHeld();
    // VOD can retrieve old packets from its source, so fill after the exact seek.
    if (!isLive && preBufferSeconds > 0) {
      do {
        await checkSource();
        final cached =
            double.tryParse(
              await native.getProperty('demuxer-cache-duration'),
            ) ??
            0;
        final text = await native.getProperty('demuxer-cache-state');
        final eof =
            text.isNotEmpty &&
            (jsonDecode(text) as Map<String, dynamic>)['eof'] == true;
        adjustment.report(
          AudioDelayProgress(
            AudioDelayPhase.buffering,
            bufferedSeconds: cached,
            targetSeconds: reserve,
          ),
        );
        if (cached >= reserve || eof) break;
        if (DateTime.now().isAfter(deadline)) {
          throw const AudioDelayAdjustmentException(AudioDelayFailure.timeout);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } while (true);
    }
    await checkSource();
    for (final entry in temporaryCache.entries) {
      await setChecked(entry.key, entry.value);
    }
    await checkSource();
    if (!wasPaused) await player.play();
  } catch (_) {
    // Sender switches/disposal own the new player state. Never resume them.
    try {
      if (adjustment.isCurrent() &&
          await native.getProperty('path') == oldPath) {
        if (changed) {
          for (final entry in temporaryCache.entries) {
            await setChecked(entry.key, entry.value);
          }
          await applyOffset(previous);
          await native.command(['seek', '$held', 'absolute+exact']);
          final restoreDeadline = DateTime.now().add(
            const Duration(seconds: 5),
          );
          while (await native.getProperty('seeking') == 'yes') {
            if (!adjustment.isCurrent() ||
                DateTime.now().isAfter(restoreDeadline)) {
              throw StateError('Restore was superseded or did not complete.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        if (!wasPaused && adjustment.isCurrent()) await player.play();
      }
    } catch (_) {
      // Disposed players cannot be restored. Preserve the original failure.
    }
    rethrow;
  }
}
