import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/shortcuts/global_shortcuts.dart';

void main() {
  group('isTextInputFocused', () {
    testWidgets('returns true when a TextField has focus', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
      );
      await tester.pump();

      expect(isTextInputFocused(), isTrue);
    });

    testWidgets('returns false when focus is on shortcut scope, not search', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalShortcutsWrapper(
            channelNavigationEnabled: false,
            child: Scaffold(
              body: Column(
                children: [
                  TextField(),
                  Expanded(
                    child: Focus(autofocus: true, child: SizedBox.expand()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(isTextInputFocused(), isFalse);
    });
  });

  group('PlayerShortcutManager', () {
    testWidgets('ignores shortcuts while search field is focused', (
      tester,
    ) async {
      final manager = PlayerShortcutManager(
        shortcuts: playerShortcutMap(channelNavigationEnabled: true),
      );
      var playPauseCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: GlobalShortcutsWrapper(
            channelNavigationEnabled: false,
            onPlayPause: () => playPauseCalled = true,
            child: const Scaffold(body: TextField(autofocus: true)),
          ),
        ),
      );
      await tester.pump();

      expect(isTextInputFocused(), isTrue);

      final context = tester.element(find.byType(TextField));
      final result = manager.handleKeypress(
        context,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
      );

      expect(result, KeyEventResult.ignored);
      expect(playPauseCalled, isFalse);
    });

    testWidgets(
      'space does not trigger play/pause while TextField is focused',
      (tester) async {
        var playPauseCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: GlobalShortcutsWrapper(
              channelNavigationEnabled: false,
              onPlayPause: () => playPauseCalled = true,
              child: const Scaffold(body: TextField(autofocus: true)),
            ),
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(playPauseCalled, isFalse);
      },
    );
  });

  group('request focus trigger', () {
    testWidgets(
      'leaving the trigger true does not steal focus from a non-text control',
      (tester) async {
        final controlFocusNode = FocusNode(debugLabel: 'NonTextControl');
        addTearDown(controlFocusNode.dispose);
        var requestFocusTrigger = true;
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return GlobalShortcutsWrapper(
                  channelNavigationEnabled: false,
                  requestFocusTrigger: requestFocusTrigger,
                  child: Scaffold(
                    body: Focus(
                      key: const ValueKey('non-text-control'),
                      focusNode: controlFocusNode,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Control'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        controlFocusNode.requestFocus();
        await tester.pump();
        expect(controlFocusNode.hasFocus, isTrue);

        setHostState(() => requestFocusTrigger = false);
        await tester.pump();
        await tester.pump();

        expect(controlFocusNode.hasFocus, isTrue);
      },
    );
  });

  group('channel navigation boundary', () {
    test('non-Live shortcut map leaves all arrow keys unmapped', () {
      final shortcuts = playerShortcutMap(channelNavigationEnabled: false);

      for (final key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowLeft,
      ]) {
        expect(shortcuts, isNot(contains(LogicalKeySet(key))));
      }
    });

    testWidgets('non-Live arrows do not trigger channel callbacks', (
      tester,
    ) async {
      var nextChannelCalls = 0;
      var previousChannelCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GlobalShortcutsWrapper(
            channelNavigationEnabled: false,
            onNextChannel: () => nextChannelCalls++,
            onPrevChannel: () => previousChannelCalls++,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();

      for (final key in <LogicalKeyboardKey>[
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowLeft,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.pump();

      expect(nextChannelCalls, 0);
      expect(previousChannelCalls, 0);
    });

    testWidgets('Live arrows still trigger next and previous channel', (
      tester,
    ) async {
      var nextChannelCalls = 0;
      var previousChannelCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: GlobalShortcutsWrapper(
            channelNavigationEnabled: true,
            onNextChannel: () => nextChannelCalls++,
            onPrevChannel: () => previousChannelCalls++,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(nextChannelCalls, 2);
      expect(previousChannelCalls, 2);
    });

    testWidgets('switching away from Live removes channel mappings', (
      tester,
    ) async {
      var enabled = true;
      var nextChannelCalls = 0;
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return GlobalShortcutsWrapper(
                channelNavigationEnabled: enabled,
                onNextChannel: () => nextChannelCalls++,
                child: const Scaffold(body: SizedBox.expand()),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(nextChannelCalls, 1);

      setHostState(() => enabled = false);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(nextChannelCalls, 1);
    });

    testWidgets('text input suppresses Live channel shortcuts', (tester) async {
      var nextChannelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: GlobalShortcutsWrapper(
            channelNavigationEnabled: true,
            onNextChannel: () => nextChannelCalled = true,
            child: const Scaffold(body: TextField(autofocus: true)),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(nextChannelCalled, isFalse);
    });
  });
}
