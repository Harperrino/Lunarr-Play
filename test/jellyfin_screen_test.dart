import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_screen.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('disconnected state shows the server connect form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const JellyfinScreen()),
    );

    expect(find.text('Connect to Jellyfin'), findsOneWidget);
    expect(find.text('SERVER'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'http://server:8096'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Check connection');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('Connecting…'), findsNothing);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('loading state shows the connecting indicator', (tester) async {
    await tester.pumpWidget(
      _host(
        const JellyfinScreen(
          initialStage: JellyfinConnectionStage.loading,
        ),
      ),
    );

    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('connected state shows the connected confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const JellyfinScreen(
          initialStage: JellyfinConnectionStage.connected,
        ),
      ),
    );

    expect(find.text('Connected'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
