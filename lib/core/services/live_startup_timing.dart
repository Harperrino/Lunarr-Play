import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/core/services/stream_log_redactor.dart';

enum LiveStartupPhase {
  hlsProbe,
  openAndSettle,
  initialTracks,
  lateAudio,
  recoveryOpenAndSettle,
  recoveryTracks,
  decodeConfirmation,
  stabilization,
  startupBuffer,
}

enum LiveStartupOutcome {
  success('success'),
  bestEffortSuccess('best-effort-success'),
  finalError('final-error'),
  sessionAborted('session-aborted');

  const LiveStartupOutcome(this.label);
  final String label;
}

Future<bool> finishLiveStartupAfterPlay({
  required LiveStartupTiming timing,
  required LiveStartupOutcome successOutcome,
  required bool Function() isSessionCurrent,
  required Future<void> Function() play,
}) async {
  if (!isSessionCurrent()) return false;
  await play();
  if (!isSessionCurrent()) {
    timing.finish(
      LiveStartupOutcome.sessionAborted,
      abortReason: 'session-replaced-after-play',
    );
    return false;
  }
  timing.finish(successOutcome);
  return true;
}

class LiveStartupTiming {
  LiveStartupTiming({Duration Function()? elapsedNow})
    : _elapsedNowOverride = elapsedNow;

  final Stopwatch _stopwatch = Stopwatch();
  final Duration Function()? _elapsedNowOverride;
  final Map<LiveStartupPhase, Duration> _phases = {
    for (final phase in LiveStartupPhase.values) phase: Duration.zero,
  };

  bool _finished = false;
  Duration? _finishedAt;
  int _candidateCount = 0;
  String _attemptLabel = '-';
  String _headerProfile = '-';
  String _delivery = '-';

  Duration get elapsed => _elapsedNowOverride?.call() ?? _stopwatch.elapsed;
  Duration get total => _finishedAt ?? elapsed;
  bool get isFinished => _finished;
  int get candidateCount => _candidateCount;
  Duration phaseDuration(LiveStartupPhase phase) => _phases[phase]!;

  void start() {
    _stopwatch
      ..reset()
      ..start();
  }

  void recordCandidate({
    required String attemptLabel,
    required String headerProfile,
    required String delivery,
  }) {
    if (_finished) return;
    _candidateCount++;
    _attemptLabel = _safeMetadata(attemptLabel);
    _headerProfile = _safeMetadata(headerProfile);
    _delivery = _safeMetadata(delivery);
  }

  Future<T> measure<T>(
    LiveStartupPhase phase,
    Future<T> Function() operation,
  ) async {
    if (_finished) return operation();
    final startedAt = elapsed;
    try {
      return await operation();
    } finally {
      if (!_finished) {
        _phases[phase] = _phases[phase]! + (elapsed - startedAt);
      }
    }
  }

  bool finish(LiveStartupOutcome outcome, {String? abortReason}) {
    if (_finished) return false;
    _finished = true;
    _finishedAt = elapsed;
    _stopwatch.stop();
    AppLogger.info(_summary(outcome, abortReason: abortReason));
    return true;
  }

  String _summary(LiveStartupOutcome outcome, {String? abortReason}) {
    int ms(LiveStartupPhase phase) => phaseDuration(phase).inMilliseconds;
    final reason = abortReason == null
        ? ''
        : ' abortReason=${_safeMetadata(abortReason)}';
    return 'LiveStartupTiming: outcome=${outcome.label}$reason '
        'attemptLabel=$_attemptLabel headerProfile=$_headerProfile '
        'deliveryType=$_delivery candidates=$_candidateCount '
        'hlsProbe=${ms(LiveStartupPhase.hlsProbe)}ms '
        'openInternalSettle=${ms(LiveStartupPhase.openAndSettle)}ms '
        'initialTrack=${ms(LiveStartupPhase.initialTracks)}ms '
        'lateAudioWait=${ms(LiveStartupPhase.lateAudio)}ms '
        'recoveryOpenSettle=${ms(LiveStartupPhase.recoveryOpenAndSettle)}ms '
        'recoveryTrack=${ms(LiveStartupPhase.recoveryTracks)}ms '
        'decodeConfirm=${ms(LiveStartupPhase.decodeConfirmation)}ms '
        'stabilization=${ms(LiveStartupPhase.stabilization)}ms '
        'startupBuffer=${ms(LiveStartupPhase.startupBuffer)}ms '
        'total=${total.inMilliseconds}ms';
  }

  static String _safeMetadata(String value) {
    final singleLine = value
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ')
        .trim();
    if (singleLine.contains('://')) return '[redacted]';
    final redacted = redactStreamText(singleLine);
    final compact = redacted.length > 120
        ? '${redacted.substring(0, 117)}...'
        : redacted;
    return compact.isEmpty ? '-' : compact;
  }
}
