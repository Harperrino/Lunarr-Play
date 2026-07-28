import 'package:flutter/material.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';

/// Minimal English-only localization host for widget tests.
class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({required this.child, this.theme, super.key});

  final Widget child;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: child,
    );
  }
}
