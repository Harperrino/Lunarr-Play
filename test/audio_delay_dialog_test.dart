import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/audio_delay_session.dart';
import 'package:m3uxtream_player/core/services/audio_delay_adjustment.dart';
import 'package:m3uxtream_player/features/player/widgets/audio_delay_dialog.dart';

import 'support/localized_test_app.dart';

void main() {
  testWidgets(
    'buffer progress can be cancelled without committing the preview',
    (tester) async {
      final gate = Completer<void>();
      final session = AudioDelaySession(
        apply: (_) async {},
        adjust: (_, context) async {
          context.report(
            const AudioDelayProgress(
              AudioDelayPhase.buffering,
              bufferedSeconds: 8,
              targetSeconds: 25,
            ),
          );
          await gate.future;
          context.check();
        },
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        LocalizedTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAudioDelayDialog(context, session),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('audio-delay-input')),
        '-15000',
      );
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('audio-delay-status')), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        8 / 25,
      );
      await tester.ensureVisible(find.text('Cancel adjustment'));
      await tester.tap(find.text('Cancel adjustment'));
      gate.complete();
      await tester.pumpAndSettle();
      expect(session.value, 0);
      expect(find.byKey(const ValueKey('audio-delay-status')), findsNothing);
    },
  );

  testWidgets(
    'track directions, readable seconds, fine steps and original comparison',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = AudioDelaySession(apply: (_) async {});
      addTearDown(session.dispose);
      await session.setMilliseconds(-15000);
      await tester.pumpWidget(
        LocalizedTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAudioDelayDialog(context, session),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sound 15 seconds earlier'), findsOneWidget);
      final picture = find.byKey(const ValueKey('audio-delay-picture-marker'));
      final sound = find.byKey(const ValueKey('audio-delay-sound-marker'));
      expect(
        tester.getCenter(sound).dx,
        lessThan(tester.getCenter(picture).dx),
      );
      await tester.tap(find.byKey(const ValueKey('audio-delay-fine')));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('audio-delay-slider')),
      );
      expect(slider.min, -15500);
      expect(slider.max, -14500);
      expect(slider.divisions, 100);
      await tester.tap(find.byTooltip('Sound later'));
      await tester.pumpAndSettle();
      expect(session.value, -14990);
      await tester.tap(find.text('Compare with original'));
      await tester.pumpAndSettle();
      expect(session.value, 0);
      expect(tester.getCenter(sound).dx, tester.getCenter(picture).dx);
      await tester.tap(find.text('Use correction'));
      await tester.pumpAndSettle();
      expect(session.value, -14990);
      await tester.enterText(
        find.byKey(const ValueKey('audio-delay-input')),
        '2500',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Sound 2.5 seconds later'), findsOneWidget);
      expect(
        tester.getCenter(sound).dx,
        greaterThan(tester.getCenter(picture).dx),
      );
    },
  );

  testWidgets('direct entry, 50ms steps, reset and invalid values', (
    tester,
  ) async {
    final writes = <int>[];
    final session = AudioDelaySession(
      apply: (value) async => writes.add(value),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAudioDelayDialog(context, session),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('audio-delay-input')),
      '-150',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(session.value, -150);
    await tester.tap(find.byTooltip('Sound later'));
    await tester.pumpAndSettle();
    expect(session.value, -100);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(session.value, 0);
    for (final value in [-60000, 60000]) {
      await tester.enterText(
        find.byKey(const ValueKey('audio-delay-input')),
        '$value',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(session.value, value);
    }
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('audio-delay-input')),
      '60001',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(session.value, 0);
    expect(writes, [-150, -100, 0, -60000, 60000, 0]);
    expect(
      find.text('Enter a whole number from −60000 to 60000.'),
      findsOneWidget,
    );
  });
}
