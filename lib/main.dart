import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/app/bootstrap/desktop_window_bootstrap.dart';
import 'package:m3uxtream_player/app/composition/jellyfin/jellyfin_playback_host_bridge.dart';
import 'package:m3uxtream_player/app/shell/main_layout_screen.dart';
import 'package:m3uxtream_player/app/services/app_error_handlers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/app/composition/xtream/widgets/series_resume_tracker.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_playback_providers.dart';
import 'package:m3uxtream_player/features/settings/providers/appearance_providers.dart';
import 'package:m3uxtream_player/l10n/generated/app_localizations.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  installAppErrorHandlers();
  AppLogger.info('App Startup: Initializing services.');

  await bootstrapDesktopWindow();

  runApp(
    ProviderScope(
      overrides: [
        jellyfinExistingPlaybackStopperProvider.overrideWith(
          (ref) =>
              () => JellyfinPlaybackHostBridge.stopExistingLunarrPlayback(ref),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearancePreferencesProvider);
    final darkTheme = AppTheme.darkThemeFor(
      accentHue: appearance.accentHue,
      surfaceTone: appearance.surfaceTone,
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // Third-party packages still using Flutter's legacy Material tree require
      // the temporary compatibility bridge during this migration.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(
        key: const ValueKey('material-ui-compatibility-bridge'),
        child: child ?? const SizedBox.shrink(),
      ),
      themeMode: ThemeMode.dark,
      theme: darkTheme,
      darkTheme: darkTheme,
      highContrastDarkTheme: AppTheme.highContrastDarkTheme,
      home: const SeriesResumeTracker(child: MainLayoutScreen()),
    );
  }
}
