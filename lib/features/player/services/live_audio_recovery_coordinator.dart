/// Mutable audio-recovery state scoped to the current live open session.
///
/// Timing, polling, media_kit calls, and Riverpod publication remain in
/// [PlayerNotifier]. This coordinator centralizes the state transitions that
/// must be reset together when a session or candidate changes.
final class LiveAudioRecoveryCoordinator {
  bool _disabledByWatchdog = false;
  bool _initialAutoOnly = false;
  bool _hadNoAudioState = false;
  bool _trackSwitchedDuringPreparation = false;
  String? _selectedTrackId;

  bool get disabledByWatchdog => _disabledByWatchdog;
  bool get initialAutoOnly => _initialAutoOnly;
  bool get hadNoAudioState => _hadNoAudioState;
  bool get trackSwitchedDuringPreparation => _trackSwitchedDuringPreparation;
  String? get selectedTrackId => _selectedTrackId;

  void resetSession() {
    _disabledByWatchdog = false;
    _trackSwitchedDuringPreparation = false;
    _selectedTrackId = null;
    resetCandidateDiscovery();
  }

  void resetCandidateDiscovery() {
    _initialAutoOnly = false;
    _hadNoAudioState = false;
  }

  void markNoAudioState({required bool initialAutoOnly}) {
    _hadNoAudioState = true;
    _initialAutoOnly = initialAutoOnly;
  }

  void recordSelectedTrack(String? trackId) {
    _selectedTrackId = trackId;
  }

  bool observePreparationTrack({
    required String selectedTrackId,
    required bool isSpecialTrack,
  }) {
    final previous = _selectedTrackId;
    final switched =
        previous != null && selectedTrackId != previous && !isSpecialTrack;
    if (switched) {
      _trackSwitchedDuringPreparation = true;
    }
    return switched;
  }

  void disableByWatchdog() {
    _disabledByWatchdog = true;
  }
}
