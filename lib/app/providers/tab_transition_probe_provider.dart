import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/performance/tab_transition_probe.dart';

final tabTransitionProbeProvider = Provider<TabTransitionProbe>((ref) {
  final probe = TabTransitionProbe();
  ref.onDispose(probe.dispose);
  return probe;
});
