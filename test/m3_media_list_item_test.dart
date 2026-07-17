import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';

Widget _mediaHarness({required VoidCallback onActivate}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    ),
    home: Scaffold(
      body: M3MediaListItem(
        title: 'News Channel',
        subtitle: const Text('Now playing'),
        leading: const Icon(Icons.tv_rounded),
        trailing: const Icon(Icons.chevron_right_rounded),
        selected: true,
        onActivate: onActivate,
      ),
    ),
  );
}

void main() {
  testWidgets('media list item keeps hierarchy and selected semantics', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(_mediaHarness(onActivate: () => activations++));

    expect(find.text('News Channel'), findsOneWidget);
    expect(find.text('Now playing'), findsOneWidget);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('News Channel')),
    );
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);

    await tester.tap(find.byIcon(Icons.tv_rounded));
    expect(activations, 1);
  });

  testWidgets('media list item exposes disabled state without activation', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: M3MediaListItem(
            title: 'Unavailable',
            leading: const Icon(Icons.tv_off_rounded),
            enabled: false,
            onActivate: () => activations++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.tv_off_rounded));
    expect(activations, 0);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('Unavailable')),
    );
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });
}
