import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_debug_mode_card.dart';
import 'package:m3uxtream_player/features/playlists/widgets/playlist_form.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'settings presentation surfaces follow normal and high-contrast roles',
    (tester) async {
      final controllers = List<TextEditingController>.generate(
        6,
        (_) => TextEditingController(),
      );
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });

      Future<void> pumpSettings({required bool highContrast}) async {
        final colors = highContrast
            ? AppTheme.highContrastDarkTheme.colorScheme
            : AppTheme.darkTheme.colorScheme;
        await tester.pumpWidget(
          _themeHost(
            highContrast: highContrast,
            child: ProviderScope(
              overrides: [
                databaseProvider.overrideWith(
                  (ref) => throw StateError(
                    'Settings presentation contract opened database',
                  ),
                ),
              ],
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      width: 760,
                      child: SettingsDebugModeCard(
                        isEnabled: false,
                        isLoading: false,
                        compact: false,
                        onChanged: (_) {},
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 760,
                      child: PlaylistForm(
                        mode: PlaylistFormMode.m3u,
                        nameController: controllers[0],
                        urlController: controllers[1],
                        hostController: controllers[2],
                        usernameController: controllers[3],
                        passwordController: controllers[4],
                        epgUrlController: controllers[5],
                        isBusy: false,
                        compact: true,
                        onModeChanged: (_) {},
                        onSubmit: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.widget<Text>(find.text('Disabled')).style?.color,
          colors.onSurfaceVariant,
        );
        expect(
          tester.widget<Text>(find.text('NAME')).style?.color,
          colors.onSurfaceVariant,
        );
        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.style?.color, colors.onSurface);
        expect(field.decoration?.fillColor, colors.surfaceContainerHigh);
      }

      await pumpSettings(highContrast: false);
      final normalColors = AppTheme.darkTheme.colorScheme;
      await pumpSettings(highContrast: true);
      final highContrastColors = AppTheme.highContrastDarkTheme.colorScheme;
      expect(
        normalColors.onSurfaceVariant,
        isNot(highContrastColors.onSurfaceVariant),
      );
    },
  );
}

Widget _themeHost({required bool highContrast, required Widget child}) {
  return MaterialApp(
    key: ValueKey<bool>(highContrast),
    theme: highContrast ? AppTheme.highContrastDarkTheme : AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}
