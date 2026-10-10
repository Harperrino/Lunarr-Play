import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/audio_delay_session.dart';
import 'package:m3uxtream_player/features/player/widgets/audio_delay_dialog.dart';

import 'support/localized_test_app.dart';

void main() {
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
