import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/stepper_control.dart';

void main() {
  testWidgets('stepper buttons expose semantics and keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: StepperControl(
              value: 15,
              min: 10,
              max: 20,
              suffix: 's',
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final decrease = find.bySemanticsLabel('Decrease value');
    final increase = find.bySemanticsLabel('Increase value');
    expect(decrease, findsOneWidget);
    expect(increase, findsOneWidget);
    expect(
      tester.getSemantics(decrease).getSemanticsData(),
      matchesSemantics(
        label: 'Decrease value',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(increase).getSemanticsData(),
      matchesSemantics(
        label: 'Increase value',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.byType(FocusableActionDetector), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, [14]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(changes, [14, 16]);

    await tester.tap(increase);
    await tester.pump();
    expect(changes, [14, 16, 16]);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('stepper buttons use high-contrast neutral control roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.highContrastDarkTheme,
        home: Scaffold(
          body: Center(
            child: StepperControl(
              value: 10,
              min: 10,
              max: 20,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final colors = AppTheme.highContrastDarkTheme.colorScheme;
    final buttonContainers = tester
        .widgetList<Container>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.minWidth == 32 &&
                widget.constraints?.maxWidth == 32 &&
                widget.constraints?.minHeight == 32 &&
                widget.constraints?.maxHeight == 32,
          ),
        )
        .toList();
    expect(buttonContainers, hasLength(2));

    final disabledDecoration =
        buttonContainers.first.decoration! as BoxDecoration;
    expect(disabledDecoration.color, colors.surfaceContainerHighest);
    expect(disabledDecoration.border!.top.color, colors.outlineVariant);

    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons.first.color, colors.onSurfaceVariant);
    expect(icons.last.color, colors.onPrimaryContainer);
  });
}
