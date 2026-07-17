import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_edge_handle.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';

void main() {
  testWidgets('edge handle keeps the M3 hit, glyph and semantic contract', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'D14EdgeHandle');
    addTearDown(focusNode.dispose);
    var pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: M3PaneEdgeHandle(
              target: M3PaneTarget.categories,
              expanded: true,
              focusNode: focusNode,
              onPressed: () => pressed++,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(M3PaneEdgeHandle)),
      const Size(M3PaneEdgeHandle.hitWidth, M3PaneEdgeHandle.hitHeight),
    );
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byType(M3PaneTargetGlyph), findsNothing);
    expect(find.byTooltip('Kategorien einklappen'), findsOneWidget);

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Kategorien einklappen'),
    );
    expect(
      semantics,
      matchesSemantics(
        label: 'Kategorien einklappen',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);

    await tester.tap(find.byType(M3PaneEdgeHandle));
    await tester.pump();
    expect(pressed, 1);
    expect(focusNode.hasFocus, isTrue);
  });
}
