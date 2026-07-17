enum LiveStreamHeaderProfile {
  appMpv,
  vlcLike,
  browserLike;

  String get label => switch (this) {
    LiveStreamHeaderProfile.appMpv => 'App/mpv',
    LiveStreamHeaderProfile.vlcLike => 'VLC-like',
    LiveStreamHeaderProfile.browserLike => 'Browser-like',
  };

  Map<String, String> get headers => switch (this) {
    LiveStreamHeaderProfile.appMpv => const {
      'User-Agent': 'mpv/0.36 m3uxtream_player',
      'Accept': '*/*',
    },
    LiveStreamHeaderProfile.vlcLike => const {
      'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
      'Accept': '*/*',
    },
    LiveStreamHeaderProfile.browserLike => const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
      'Accept': '*/*',
    },
  };
}

enum StreamingDiagnosticPhase {
  started,
  prebufferStarted,
  prebufferReached,
  prebufferTimedOut,
  prebufferCancelled,
  success,
  failure,
}

extension StreamingDiagnosticPhaseX on StreamingDiagnosticPhase {
  String get label => switch (this) {
    StreamingDiagnosticPhase.started => 'STARTED',
    StreamingDiagnosticPhase.prebufferStarted => 'PREBUFFER START',
    StreamingDiagnosticPhase.prebufferReached => 'PREBUFFER REACHED',
    StreamingDiagnosticPhase.prebufferTimedOut => 'PREBUFFER TIMEOUT',
    StreamingDiagnosticPhase.prebufferCancelled => 'PREBUFFER CANCELLED',
    StreamingDiagnosticPhase.success => 'SUCCESS',
    StreamingDiagnosticPhase.failure => 'FAILURE',
  };
}

enum StreamingFailureKind {
  offline,
  unauthorized,
  forbidden,
  tokenExpired,
  notFound,
  timeout,
  invalidHls,
  providerBlocked,
  unsupportedCodec,
  redirectIssue,
  unknown,
}

class StreamingFallbackAttempt {
  const StreamingFallbackAttempt({
    required this.sourceUrl,
    required this.playbackUrl,
    required this.label,
    required this.headerProfile,
    required this.deliveryType,
  });

  final String sourceUrl;
  final String playbackUrl;
  final String label;
  final LiveStreamHeaderProfile headerProfile;
  final String deliveryType;

  Map<String, String> get headers => headerProfile.headers;
}

class StreamingDiagnosticEvent {
  const StreamingDiagnosticEvent({
    required this.timestamp,
    required this.phase,
    required this.fallbackLabel,
    required this.headerProfile,
    required this.deliveryType,
    required this.sourceUrlRedacted,
    required this.playbackUrlRedacted,
    this.channelName,
    this.channelId,
    this.httpStatus,
    this.contentType,
    this.mpvError,
    this.failureKind,
    this.duration = Duration.zero,
    this.diagnosisNote,
  });

  final DateTime timestamp;
  final StreamingDiagnosticPhase phase;
  final String? channelName;
  final String? channelId;
  final String sourceUrlRedacted;
  final String playbackUrlRedacted;
  final String fallbackLabel;
  final LiveStreamHeaderProfile headerProfile;
  final String deliveryType;
  final int? httpStatus;
  final String? contentType;
  final String? mpvError;
  final StreamingFailureKind? failureKind;
  final Duration duration;
  final String? diagnosisNote;

  bool get success => phase == StreamingDiagnosticPhase.success;
  bool get failed => phase == StreamingDiagnosticPhase.failure;

  String get summaryLine {
    final parts = <String>[
      '[${timestamp.toIso8601String()}]',
      phase.label,
      ?channelName,
      fallbackLabel,
      headerProfile.label,
      deliveryType,
      playbackUrlRedacted,
      if (httpStatus != null) 'HTTP $httpStatus',
      if (contentType != null) 'Content-Type=$contentType',
      if (failureKind != null) 'Kind=${failureKind!.name}',
      ?diagnosisNote,
    ];
    return parts.join(' | ');
  }

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'phase': phase.name,
    'channelName': channelName,
    'channelId': channelId,
    'sourceUrlRedacted': sourceUrlRedacted,
    'playbackUrlRedacted': playbackUrlRedacted,
    'fallbackLabel': fallbackLabel,
    'headerProfile': headerProfile.name,
    'deliveryType': deliveryType,
    'httpStatus': httpStatus,
    'contentType': contentType,
    'mpvError': mpvError,
    'failureKind': failureKind?.name,
    'durationMs': duration.inMilliseconds,
    'diagnosisNote': diagnosisNote,
  };
}

class StreamingDiagnosticSnapshot {
  const StreamingDiagnosticSnapshot({required this.events});

  final List<StreamingDiagnosticEvent> events;

  StreamingDiagnosticEvent? get lastFailure {
    for (var i = events.length - 1; i >= 0; i--) {
      final event = events[i];
      if (event.failed) return event;
    }
    return null;
  }

  List<StreamingDiagnosticEvent> get failureEvents =>
      events.where((event) => event.failed).toList(growable: false);

  String toClipboardText() {
    if (events.isEmpty) return 'No streaming diagnostics captured.';
    return events.map((event) => event.summaryLine).join('\n');
  }
}

class StreamConnectionProbeResult {
  const StreamConnectionProbeResult({
    required this.requestedUri,
    required this.resolvedUri,
    required this.duration,
    required this.redirectChain,
    required this.usedHead,
    required this.usedRange,
    this.redirectLimitExceeded = false,
    this.httpStatus,
    this.contentType,
    this.bodySample,
    this.hlsAudioRenditions = const [],
    this.hlsCodecs = const [],
    this.timedOut = false,
  });

  final Uri requestedUri;
  final Uri resolvedUri;
  final Duration duration;
  final List<Uri> redirectChain;
  final bool usedHead;
  final bool usedRange;
  final bool redirectLimitExceeded;
  final int? httpStatus;
  final String? contentType;
  final String? bodySample;
  final List<String> hlsAudioRenditions;
  final List<String> hlsCodecs;
  final bool timedOut;

  bool get redirected =>
      redirectChain.isNotEmpty || requestedUri != resolvedUri;
  bool get looksLikeHls =>
      (contentType?.toLowerCase().contains('mpegurl') ?? false) ||
      (bodySample?.contains('#EXTM3U') ?? false) ||
      resolvedUri.path.toLowerCase().endsWith('.m3u8');
  bool get hasHlsHints => hlsAudioRenditions.isNotEmpty || hlsCodecs.isNotEmpty;
  String? get hlsHintSummary {
    final parts = <String>[];
    if (hlsAudioRenditions.isNotEmpty) {
      parts.add('AUDIO=${hlsAudioRenditions.join(', ')}');
    }
    if (hlsCodecs.isNotEmpty) {
      parts.add('CODECS=${hlsCodecs.join(', ')}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' | ');
  }

  bool get success =>
      !timedOut &&
      !redirectLimitExceeded &&
      httpStatus != null &&
      httpStatus! >= 200 &&
      httpStatus! < 400;

  StreamConnectionProbeResult copyWithDuration(Duration duration) {
    return copyWith(duration: duration);
  }

  StreamConnectionProbeResult copyWith({
    Uri? requestedUri,
    Uri? resolvedUri,
    Duration? duration,
    List<Uri>? redirectChain,
    bool? usedHead,
    bool? usedRange,
    bool? redirectLimitExceeded,
    int? httpStatus,
    String? contentType,
    String? bodySample,
    List<String>? hlsAudioRenditions,
    List<String>? hlsCodecs,
    bool? timedOut,
  }) {
    return StreamConnectionProbeResult(
      requestedUri: requestedUri ?? this.requestedUri,
      resolvedUri: resolvedUri ?? this.resolvedUri,
      duration: duration ?? this.duration,
      redirectChain: redirectChain ?? this.redirectChain,
      usedHead: usedHead ?? this.usedHead,
      usedRange: usedRange ?? this.usedRange,
      redirectLimitExceeded:
          redirectLimitExceeded ?? this.redirectLimitExceeded,
      httpStatus: httpStatus ?? this.httpStatus,
      contentType: contentType ?? this.contentType,
      bodySample: bodySample ?? this.bodySample,
      hlsAudioRenditions: hlsAudioRenditions ?? this.hlsAudioRenditions,
      hlsCodecs: hlsCodecs ?? this.hlsCodecs,
      timedOut: timedOut ?? this.timedOut,
    );
  }

  Map<String, Object?> toJson() => {
    'requestedUri': requestedUri.toString(),
    'resolvedUri': resolvedUri.toString(),
    'durationMs': duration.inMilliseconds,
    'redirectChain': redirectChain
        .map((uri) => uri.toString())
        .toList(growable: false),
    'usedHead': usedHead,
    'usedRange': usedRange,
    'redirectLimitExceeded': redirectLimitExceeded,
    'httpStatus': httpStatus,
    'contentType': contentType,
    'bodySample': bodySample,
    'hlsAudioRenditions': hlsAudioRenditions,
    'hlsCodecs': hlsCodecs,
    'timedOut': timedOut,
  };
}

class StreamFailureClassification {
  const StreamFailureClassification({
    required this.kind,
    required this.possible,
    this.reason,
  });

  final StreamingFailureKind kind;
  final bool possible;
  final String? reason;

  String get label => possible ? 'possible ${kind.name}' : kind.name;
}

class StreamingDiagnosticsSettings {
  const StreamingDiagnosticsSettings({
    required this.autoFallbackEnabled,
    required this.showOnErrorEnabled,
  });

  final bool autoFallbackEnabled;
  final bool showOnErrorEnabled;
}
