import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

import 'support/localized_test_app.dart';

void main() {
  testWidgets('English is the generated and forced application locale', (
    tester,
  ) async {
    late BuildContext localizedContext;
    await tester.pumpWidget(
      LocalizedTestApp(
        child: Builder(
          builder: (context) {
            localizedContext = context;
            return Text(context.l10n.appTitle);
          },
        ),
      ),
    );

    expect(Localizations.localeOf(localizedContext), const Locale('en'));
    expect(find.text('Lunarr Player'), findsOneWidget);
  });
}
