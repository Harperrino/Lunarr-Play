import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_credentials_store.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_screen.dart';

import 'jellyfin_test_helpers.dart';

const _publicInfoJson = {
  'ServerName': 'Media Server',
  'Version': '10.10.3',
  'Id': 'server-id-1',
};

const _authResponseJson = {
  'User': {'Name': 'alice', 'Id': 'user-id-1'},
  'AccessToken': 'token-abc-123',
  'ServerId': 'server-id-1',
};

MockClient _happyTransport() {
  final library = jellyfinHappyHandler();
  return MockClient((request) async {
    if (request.url.path == '/Users/AuthenticateByName') {
      return http.Response(jsonEncode(_authResponseJson), 200);
    }
    if (request.url.path == '/Sessions/Logout') {
      return http.Response('', 204);
    }
    if (request.url.path == '/System/Info/Public') {
      return http.Response(jsonEncode(_publicInfoJson), 200);
    }
    return library(request);
  });
}

Widget _host(MockClient transport) {
  return ProviderScope(
    overrides: [
      jellyfinApiClientProvider.overrideWithValue(
        JellyfinApiClient(transport: transport),
      ),
      jellyfinCredentialsStoreProvider.overrideWithValue(
        InMemoryJellyfinCredentialsStore(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: const JellyfinScreen()),
    ),
  );
}

Future<void> _pumpHost(WidgetTester tester, MockClient transport) async {
  await tester.pumpWidget(_host(transport));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on the server form with an enabled check button', (
    tester,
  ) async {
    await _pumpHost(tester, _happyTransport());

    expect(find.text('Connect to Jellyfin'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'http://server:8096'),
      findsOneWidget,
    );
    final button = find.widgetWithText(FilledButton, 'Check connection');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('successful server check reveals the sign-in form', (
    tester,
  ) async {
    await _pumpHost(tester, _happyTransport());

    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();

    expect(find.text('Server verified'), findsOneWidget);
    expect(find.text('Media Server'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields, hasLength(2));
    expect(fields[1].obscureText, isTrue);
  });

  testWidgets('wrong password shows a comprehensible 401 error state', (
    tester,
  ) async {
    final transport = MockClient((request) async {
      if (request.url.path == '/Users/AuthenticateByName') {
        return http.Response('unauthorized', 401);
      }
      return http.Response(jsonEncode(_publicInfoJson), 200);
    });
    await _pumpHost(tester, transport);

    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'http://server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Unencrypted Jellyfin connection'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue over HTTP'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Unencrypted Jellyfin connection'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Incorrect username or password.'), findsOneWidget);
  });

  testWidgets('correct login shows the home screen and signs out', (
    tester,
  ) async {
    jellyfinTallViewport(tester);
    await _pumpHost(tester, _happyTransport());

    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'http://server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue over HTTP'));
    await tester.pumpAndSettle();

    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Libraries'), findsOneWidget);
    expect(find.text('Signed in as alice'), findsOneWidget);
    expect(find.text('http://server:8096'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Check connection'),
      findsOneWidget,
    );
    expect(find.text('Libraries'), findsNothing);
  });

  testWidgets('access token and password never appear in log output', (
    tester,
  ) async {
    AppLogger.clearHistory();

    await _pumpHost(tester, _happyTransport());
    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'http://server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue over HTTP'));
    await tester.pumpAndSettle();

    final messages = AppLogger.recentEvents
        .where((entry) => entry.message.contains('Jellyfin'))
        .map((entry) => entry.message)
        .join('\n');
    expect(messages, isNot(contains('token-abc-123')));
    expect(messages, isNot(contains('secret-pw')));
    expect(messages, contains('Authentication succeeded'));
  });

  testWidgets('HTTP warning can be cancelled before authentication', (
    tester,
  ) async {
    var authenticationCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/Users/AuthenticateByName') {
        authenticationCalls++;
        return http.Response(jsonEncode(_authResponseJson), 200);
      }
      return http.Response(jsonEncode(_publicInfoJson), 200);
    });

    await _pumpHost(tester, transport);
    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'http://server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('uses HTTP'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Unencrypted Jellyfin connection'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(authenticationCalls, 0);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('password Enter key uses the HTTP confirmation flow', (
    tester,
  ) async {
    var authenticationCalls = 0;
    final library = jellyfinHappyHandler();
    final transport = MockClient((request) async {
      if (request.url.path == '/Users/AuthenticateByName') {
        authenticationCalls++;
        return http.Response(jsonEncode(_authResponseJson), 200);
      }
      if (request.url.path == '/System/Info/Public') {
        return http.Response(jsonEncode(_publicInfoJson), 200);
      }
      return library(request);
    });

    await _pumpHost(tester, transport);
    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'http://server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pw');
    await tester.tap(find.byType(TextField).at(1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Unencrypted Jellyfin connection'), findsOneWidget);
    expect(authenticationCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue over HTTP'));
    await tester.pumpAndSettle();

    expect(authenticationCalls, 1);
    expect(find.text('Continue watching'), findsOneWidget);
  });

  testWidgets('HTTPS login has no HTTP warning or confirmation dialog', (
    tester,
  ) async {
    await _pumpHost(tester, _happyTransport());
    await tester.enterText(
      find.widgetWithText(TextField, 'http://server:8096'),
      'https://server:8096',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Check connection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('uses HTTP'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Unencrypted Jellyfin connection'), findsNothing);
    expect(find.text('Continue watching'), findsOneWidget);
  });
}
