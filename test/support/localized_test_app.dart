import 'package:material_ui/material_ui.dart';
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
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Mirrors the production compatibility boundary for legacy packages.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(
        key: const ValueKey('material-ui-compatibility-bridge'),
        child: child ?? const SizedBox.shrink(),
      ),
      theme: theme,
      home: child,
    );
  }
}
