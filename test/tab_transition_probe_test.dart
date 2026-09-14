import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/app/performance/tab_transition_probe.dart';
import 'package:m3uxtream_player/app/performance/tab_transition_provider_observer.dart';
import 'package:m3uxtream_player/app/providers/tab_transition_probe_provider.dart';

void main() {
  testWidgets('records cold and warm transitions with bounded samples', (
    tester,
  ) async {
    var rss = 1000;
    final probe = TabTransitionProbe(enabled: true, currentRss: () => rss);
    addTearDown(probe.dispose);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));

    probe.begin(fromIndex: 0, toIndex: 1);
    probe.recordRequest();
    probe.recordRequest();
    rss = 1300;
    probe.markContentMounted(1);
    await tester.pump();
    await tester.pump();

    expect(probe.samples, hasLength(1));
    expect(probe.samples.single.warm, isFalse);
    expect(probe.samples.single.firstRasterFrame, isNotNull);
    expect(probe.samples.single.requestCount, 2);
    expect(probe.samples.single.rssDeltaBytes, 300);

    probe.begin(fromIndex: 0, toIndex: 1);
    probe.markContentMounted(1);
    await tester.pump();
    await tester.pump();

    expect(probe.samples, hasLength(2));
    expect(probe.samples.last.warm, isTrue);
  });

  testWidgets('ignores stale markers after a newer tab transition', (
    tester,
  ) async {
    final probe = TabTransitionProbe(enabled: true, currentRss: () => 0);
    addTearDown(probe.dispose);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));

    probe.begin(fromIndex: 0, toIndex: 1);
    probe.begin(fromIndex: 1, toIndex: 2);
    probe.markContentMounted(1);
    await tester.pump();
    expect(probe.samples, isEmpty);

    probe.markContentMounted(2);
    await tester.pump();
    await tester.pump();
    expect(probe.samples.single.toIndex, 2);
  });

  testWidgets('provider observer counts async loads only during transitions', (
    tester,
  ) async {
    final probe = TabTransitionProbe(enabled: true, currentRss: () => 0);
    final provider = FutureProvider<int>((ref) async => 1);
    final container = ProviderContainer(
      overrides: [tabTransitionProbeProvider.overrideWithValue(probe)],
      observers: const [TabTransitionProviderObserver()],
    );
    addTearDown(() {
      container.dispose();
      probe.dispose();
    });
    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));

    probe.begin(fromIndex: 0, toIndex: 1);
    expect(await container.read(provider.future), 1);
    probe.markContentMounted(1);
    await tester.pump();
    await tester.pump();

    expect(probe.samples.single.requestCount, 1);
  });
}
