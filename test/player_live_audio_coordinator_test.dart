import 'package:flutter_test/flutter_test.dart';

import 'package:m3uxtream_player/features/player/services/live_audio_recovery_coordinator.dart';

void main() {
  test('session reset clears every candidate and watchdog flag', () {
    final coordinator = LiveAudioRecoveryCoordinator()
      ..markNoAudioState(initialAutoOnly: true)
      ..recordSelectedTrack('1')
      ..disableByWatchdog();

    expect(
      coordinator.observePreparationTrack(
        selectedTrackId: '2',
        isSpecialTrack: false,
      ),
      isTrue,
    );

    coordinator.resetSession();

    expect(coordinator.disabledByWatchdog, isFalse);
    expect(coordinator.initialAutoOnly, isFalse);
    expect(coordinator.hadNoAudioState, isFalse);
    expect(coordinator.trackSwitchedDuringPreparation, isFalse);
    expect(coordinator.selectedTrackId, isNull);
  });

  test('candidate reset preserves session selection and watchdog state', () {
    final coordinator = LiveAudioRecoveryCoordinator()
      ..markNoAudioState(initialAutoOnly: true)
      ..recordSelectedTrack('1')
      ..disableByWatchdog()
      ..resetCandidateDiscovery();

    expect(coordinator.initialAutoOnly, isFalse);
    expect(coordinator.hadNoAudioState, isFalse);
    expect(coordinator.selectedTrackId, '1');
    expect(coordinator.disabledByWatchdog, isTrue);
  });

  test('special tracks never count as preparation switches', () {
    final coordinator = LiveAudioRecoveryCoordinator()
      ..recordSelectedTrack('1');

    expect(
      coordinator.observePreparationTrack(
        selectedTrackId: 'auto',
        isSpecialTrack: true,
      ),
      isFalse,
    );
    expect(coordinator.trackSwitchedDuringPreparation, isFalse);
  });

  test('real changed track latches preparation switch state', () {
    final coordinator = LiveAudioRecoveryCoordinator()
      ..recordSelectedTrack('1');

    expect(
      coordinator.observePreparationTrack(
        selectedTrackId: '2',
        isSpecialTrack: false,
      ),
      isTrue,
    );
    expect(coordinator.trackSwitchedDuringPreparation, isTrue);
    expect(coordinator.selectedTrackId, '1');
  });
}
