@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/core/services/settings_layout_geometry.dart';
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
import 'package:m3uxtream_player/shared/theme/high_contrast_theme_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_edge_handle.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';
import 'package:m3uxtream_player/features/settings/widgets/settings_section_navigation.dart';

const _sceneKey = ValueKey<String>('d14-settings-edge-scene');

ThemeData _themeFor(String variant) {
  final colors = switch (variant) {
    'neutral' => AppColorRoles.darkScheme,
    'yellow' => AppColorRoles.darkSchemeFor(accentHue: 60, surfaceTone: 0.5),
    'green' => AppColorRoles.darkSchemeFor(accentHue: 120, surfaceTone: 0.5),
    'blue' => AppColorRoles.darkSchemeFor(accentHue: 220, surfaceTone: 0.5),
    'high-contrast' => HighContrastThemeRoles.colorScheme,
    _ => throw ArgumentError.value(variant),
  };
  return ThemeData(useMaterial3: true, colorScheme: colors);
}

Widget _scene() {
  return Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: _sceneKey,
        child: SizedBox(
          width: 1000,
          height: 560,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: SettingsLayoutMetrics.sectionNavigationWidth,
                    child: SettingsSectionNavigation(
                      selectedSection: SettingsSection.playlistSetup,
                      onGeneralSelected: _noop,
                      onPlaylistSetupSelected: _noop,
                      onSavedPlaylistsSelected: _noop,
                    ),
                  ),
                ),
                const SizedBox(
                  width: SettingsLayoutMetrics.navigationContentGap,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 16.0;
                      const senderWidth = 180.0;
                      final sideWidth =
                          (constraints.maxWidth - senderWidth - gap * 2) / 2;
                      final categorySeam = sideWidth + gap / 2;
                      final senderSeam =
                          sideWidth + gap + senderWidth + gap / 2;
                      final handleTop =
                          constraints.maxHeight / 2 -
                          M3PaneEdgeHandle.hitHeight / 2;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _pane(
                                  'Kategorien',
                                  Icons.layers_rounded,
                                ),
                              ),
                              const SizedBox(width: gap),
                              SizedBox(
                                width: senderWidth,
                                child: _pane(
                                  'Senderliste',
                                  Icons.format_list_bulleted_rounded,
                                ),
                              ),
                              const SizedBox(width: gap),
                              Expanded(
                                child: _pane(
                                  'Player',
                                  Icons.play_circle_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            left: categorySeam - M3PaneEdgeHandle.hitWidth / 2,
                            top: handleTop,
                            child: const M3PaneEdgeHandle(
                              target: M3PaneTarget.categories,
                              expanded: true,
                              onPressed: _noop,
                            ),
                          ),
                          Positioned(
                            left: senderSeam - M3PaneEdgeHandle.hitWidth / 2,
                            top: handleTop,
                            child: const M3PaneEdgeHandle(
                              target: M3PaneTarget.channels,
                              expanded: false,
                              onPressed: _noop,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _pane(String title, IconData icon) {
  return Builder(
    builder: (context) => AppSurface(
      level: AppSurfaceLevel.low,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    ),
  );
}

void main() {
  for (final variant in ['neutral', 'high-contrast']) {
    testWidgets('D14 $variant settings and edge scene', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _themeFor(variant),
          home: _scene(),
        ),
      );
      await tester.pump();

      expect(find.byType(M3PaneEdgeHandle), findsNWidgets(2));
      expect(find.byType(M3PaneToggleButton), findsNothing);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_sceneKey),
        matchesGoldenFile('goldens/d14_settings_edge_$variant.png'),
      );
    });
  }
}

void _noop() {}
