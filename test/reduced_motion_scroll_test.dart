import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/diagnostics/widgets/ui_log_console_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_layout.dart';

Widget _motionHost({required bool disableAnimations, required Widget child}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );
}

Widget _settingsLayout() {
  return const SizedBox(
    width: 1200,
    height: 500,
    child: SettingsLayout(
      topSection: SizedBox(height: 320, child: Text('General content')),
      playlistForm: SizedBox(
        height: 320,
        child: Text('Playlist setup content'),
      ),
      playlistSection: SizedBox(
        height: 320,
        child: Text('Saved playlists content'),
      ),
    ),
  );
}

Finder _settingsScrollable() => find.descendant(
  of: find.byKey(const ValueKey('settings-scroll')),
  matching: find.byType(Scrollable),
);

List<String> _logs(int count) =>
    List<String>.generate(count, (index) => 'diagnostic line $index');

void main() {
  testWidgets(
    'settings section navigation uses zero duration for reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _motionHost(disableAnimations: true, child: _settingsLayout()),
      );
      await tester.pump();

      final position = tester
          .state<ScrollableState>(_settingsScrollable())
          .position;
      await tester.tap(find.text('Saved playlists'));
      await tester.pump();

      expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
    },
  );

  testWidgets('settings section navigation keeps its normal 200ms animation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _motionHost(disableAnimations: false, child: _settingsLayout()),
    );
    await tester.pump();

    final position = tester
        .state<ScrollableState>(_settingsScrollable())
        .position;
    await tester.tap(find.text('Saved playlists'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(position.pixels, greaterThan(0));
    expect(position.pixels, lessThan(position.maxScrollExtent));
    await tester.pump(const Duration(milliseconds: 200));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
  });

  testWidgets(
    'diagnostic log autoscroll uses zero duration for reduced motion',
    (tester) async {
      var logs = <String>['initial'];
      late StateSetter setHostState;

      await tester.pumpWidget(
        _motionHost(
          disableAnimations: true,
          child: SizedBox(
            width: 600,
            height: 300,
            child: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return UiLogConsoleCard(logs: logs, onClear: () {});
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      setHostState(() => logs = _logs(100));
      await tester.pump();
      await tester.pump();

      expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
    },
  );

  testWidgets('diagnostic log autoscroll keeps its normal 200ms animation', (
    tester,
  ) async {
    var logs = <String>['initial'];
    late StateSetter setHostState;

    await tester.pumpWidget(
      _motionHost(
        disableAnimations: false,
        child: SizedBox(
          width: 600,
          height: 300,
          child: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return UiLogConsoleCard(logs: logs, onClear: () {});
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    setHostState(() => logs = _logs(100));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(position.pixels, greaterThan(0));
    expect(position.pixels, lessThan(position.maxScrollExtent));
    await tester.pump(const Duration(milliseconds: 200));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
  });
}
