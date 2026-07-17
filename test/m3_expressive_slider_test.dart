import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/m3_expressive_slider.dart';

class _SliderHost extends StatefulWidget {
  const _SliderHost({required this.events, this.enabled = true});

  final List<String> events;
  final bool enabled;

  @override
  State<_SliderHost> createState() => _SliderHostState();
}

class _SliderHostState extends State<_SliderHost> {
  double value = 0.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: M3ExpressiveSlider(
        value: value,
        min: 0,
        max: 1,
        bufferedValue: 0.8,
        enabled: widget.enabled,
        semanticFormatter: (nextValue) =>
            'Testwert ${(nextValue * 100).round()} Prozent',
        onChangeStart: (nextValue) {
          widget.events.add('start:$nextValue');
        },
        onChanged: (nextValue) {
          widget.events.add('changed:$nextValue');
          setState(() => value = nextValue);
        },
        onChangeEnd: (nextValue) {
          widget.events.add('end:$nextValue');
        },
      ),
    );
  }
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tap and drag emit one ordered callback lifecycle', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(_app(_SliderHost(events: events)));

    final slider = find.byType(M3ExpressiveSlider);
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + rect.width * 0.8, rect.center.dy));

    expect(events.first, startsWith('start:'));
    expect(events.last, startsWith('end:'));
    expect(events.where((event) => event.startsWith('start:')), hasLength(1));
    expect(events.where((event) => event.startsWith('end:')), hasLength(1));
    expect(events.where((event) => event.startsWith('changed:')), hasLength(1));

    events.clear();
    final gesture = await tester.startGesture(
      Offset(rect.left + 24, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.right - 24, rect.center.dy));
    await gesture.up();
    await tester.pump();

    expect(events.where((event) => event.startsWith('start:')), hasLength(1));
    expect(events.where((event) => event.startsWith('end:')), hasLength(1));
    expect(events.first, startsWith('start:'));
    expect(events.last, startsWith('end:'));
  });

  testWidgets('arrow keys and Home/End update the value', (tester) async {
    final values = <double>[];
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 320,
          child: M3ExpressiveSlider(
            value: 0.5,
            onChanged: values.add,
            semanticFormatter: (value) => value.toStringAsFixed(2),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(M3ExpressiveSlider));
    values.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(values.single, closeTo(0.51, 0.0001));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(values.last, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(values.last, 1);
  });

  testWidgets('Semantics exposes slider state and increase/decrease actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(const SizedBox(width: 320, child: _SemanticSlider())),
    );

    final node = tester.getSemantics(find.byType(M3ExpressiveSlider));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isSlider, isTrue);
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    expect(node.value, '50 Prozent');
    expect(node.increasedValue, '51 Prozent');
    semantics.dispose();
  });

  testWidgets('disabled sliders do not react to pointer or keyboard input', (
    tester,
  ) async {
    final events = <String>[];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(_SliderHost(events: events, enabled: false)));

    final slider = find.byType(M3ExpressiveSlider);
    final rect = tester.getRect(slider);
    await tester.tapAt(rect.center);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(events, isEmpty);
    final node = tester.getSemantics(slider);
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    expect(data.hasAction(SemanticsAction.decrease), isFalse);
    semantics.dispose();
  });
}

class _SemanticSlider extends StatelessWidget {
  const _SemanticSlider();

  @override
  Widget build(BuildContext context) => M3ExpressiveSlider(
    value: 0.5,
    onChanged: (_) {},
    semanticFormatter: (value) => '${(value * 100).round()} Prozent',
  );
}
