import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/epg/widgets/epg_interactive_surface.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'EPG interactive surface exposes and handles keyboard activation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: EpgInteractiveSurface(
                semanticLabel: 'EPG test action',
                onTap: () => activations++,
                child: const SizedBox(
                  width: 180,
                  height: 56,
                  child: Text('Test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final action = find.bySemanticsLabel(RegExp('EPG test action'));
      expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      final node = tester.getSemantics(action);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(activations, 1);

      await tester.tap(find.byType(EpgInteractiveSurface));
      await tester.pump();
      expect(activations, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(activations, 4);
      semantics.dispose();
    },
  );
}
