/// Origin of an EPG refresh request.
enum EpgSyncOrigin { manual, automatic }

/// Lifecycle of one playlist-specific EPG refresh job.
enum EpgSyncStatus { queued, syncing, succeeded, failed }

class EpgSyncJob {
  const EpgSyncJob({
    required this.playlistId,
    required this.status,
    required this.origin,
    required this.requestedAt,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  final int playlistId;
  final EpgSyncStatus status;
  final EpgSyncOrigin origin;
  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Object? error;

  bool get isActive =>
      status == EpgSyncStatus.queued || status == EpgSyncStatus.syncing;

  bool get isComplete =>
      status == EpgSyncStatus.succeeded || status == EpgSyncStatus.failed;

  EpgSyncJob copyWith({
    EpgSyncStatus? status,
    EpgSyncOrigin? origin,
    DateTime? startedAt,
    DateTime? completedAt,
    Object? error,
    bool clearError = false,
  }) {
    return EpgSyncJob(
      playlistId: playlistId,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      requestedAt: requestedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}
