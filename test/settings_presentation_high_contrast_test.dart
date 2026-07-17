import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/core_providers.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_debug_mode_card.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_form.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_playlist_section.dart';
import 'package:m3uxtream_player/shared/theme/app_theme.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';

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
                      child: SettingsPlaylistForm(
                        mode: SettingsPlaylistFormMode.m3u,
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 760,
                      child: SettingsPlaylistSection(
                        items: const [],
                        isLoading: false,
                        errorMessage: null,
                        isSyncing: false,
                        isEpgSyncing: false,
                        isBusy: false,
                        compact: false,
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
        expect(
          tester.widget<Text>(find.text('No playlists yet')).style?.color,
          colors.onSurface,
        );
        expect(
          tester
              .widget<Text>(
                find.text('Add an M3U or Xtream playlist to get started.'),
              )
              .style
              ?.color,
          colors.onSurfaceVariant,
        );
        expect(
          tester.widget<Icon>(find.byIcon(Icons.inbox_rounded)).color,
          colors.outline,
        );
        final emptySurface = tester.widget<AppSurface>(
          find
              .ancestor(
                of: find.byIcon(Icons.inbox_rounded),
                matching: find.byType(AppSurface),
              )
              .first,
        );
        expect(emptySurface.level, AppSurfaceLevel.low);
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
