import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:m3uxtream_player/app/bootstrap/desktop_window_bootstrap.dart';
import 'package:m3uxtream_player/app/shell/main_layout_screen.dart';
import 'package:m3uxtream_player/core/constants/app_identity.dart';
import 'package:m3uxtream_player/core/logger/app_error_handlers.dart';
import 'package:m3uxtream_player/core/logger/app_logger.dart';
import 'package:m3uxtream_player/features/xtream/widgets/series_resume_tracker.dart';
import 'package:m3uxtream_player/features/settings/providers/appearance_providers.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  installAppErrorHandlers();
  AppLogger.info('App Startup: Initializing services.');

  await bootstrapDesktopWindow();

  runApp(const ProviderScope(child: MyApp()));
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
      title: AppIdentity.displayName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: darkTheme,
      darkTheme: darkTheme,
      highContrastDarkTheme: AppTheme.highContrastDarkTheme,
      home: const SeriesResumeTracker(child: MainLayoutScreen()),
    );
  }
}
