@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
import 'package:m3uxtream_player/shared/theme/high_contrast_theme_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/category_sidebar.dart';
import 'package:m3uxtream_player/shared/widgets/m3_media_list_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';
import 'package:m3uxtream_player/shared/widgets/m3_tab_shelf.dart';

const _sceneKey = ValueKey<String>('d13-live-depth-scene');

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
          width: 1120,
          height: 600,
          child: Builder(
            builder: (context) {
              final colors = Theme.of(context).colorScheme;
              return ColoredBox(
                color: colors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            M3NavigationItem(
                              label: 'Live TV',
                              icon: Icons.live_tv_rounded,
                              selected: true,
                              expanded: false,
                              visualRole:
                                  M3NavigationItemVisualRole.navigationRail,
                              onPressed: _noop,
                            ),
                            const SizedBox(height: 4),
                            M3NavigationItem(
                              label: 'Library',
                              icon: Icons.video_library_rounded,
                              expanded: false,
                              visualRole:
                                  M3NavigationItemVisualRole.navigationRail,
                              onPressed: _noop,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppSurface(
                              level: AppSurfaceLevel.low,
                              elevation: AppElevation.level1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Live chrome',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  M3PaneToggleButton(
                                    target: M3PaneTarget.categories,
                                    expanded: true,
                                    onPressed: _noop,
                                  ),
                                  M3PaneToggleButton(
                                    target: M3PaneTarget.channels,
                                    expanded: true,
                                    onPressed: _noop,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            M3TabShelf(
                              child: const DefaultTabController(
                                length: 2,
                                child: TabBar(
                                  isScrollable: true,
                                  tabs: [
                                    Tab(text: 'Live'),
                                    Tab(text: 'Favorites'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  CategorySidebar(
                                    groups: const ['News', 'Sports', 'Music'],
                                    selectedGroup: 'News',
                                    onSelected: _select,
                                    width: 232,
                                    headerActions: M3PaneToggleButton(
                                      target: M3PaneTarget.categories,
                                      expanded: true,
                                      onPressed: _noop,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: _senderPane(context)),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 310,
                                    child: _playerPane(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Widget _senderPane(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return AppSurface(
    level: AppSurfaceLevel.low,
    elevation: AppElevation.level1,
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Senderliste', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final channel in const [
                'News HD',
                'World Sports',
                'Radio One',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: M3MediaListItem(
                    title: channel,
                    leading: Icon(Icons.tv_rounded, color: colors.primary),
                    subtitle: Text(
                      'Live stream',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    compact: true,
                    surfaceLevel: AppSurfaceLevel.base,
                    surfaceColor: Colors.transparent,
                    onActivate: _noop,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _playerPane(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return AppSurface(
    level: AppSurfaceLevel.standard,
    elevation: AppElevation.level2,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Player', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 48,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ready to play',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}

void main() {
  for (final variant in ['neutral', 'high-contrast']) {
    testWidgets('D13 $variant live depth scene', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _themeFor(variant),
          home: _scene(),
        ),
      );
      await tester.pump();

      final surfaces = tester.widgetList<AppSurface>(find.byType(AppSurface));
      expect(
        surfaces.any(
          (surface) =>
              surface.level == AppSurfaceLevel.low &&
              surface.elevation == AppElevation.level1,
        ),
        isTrue,
      );
      expect(
        surfaces.any(
          (surface) =>
              surface.level == AppSurfaceLevel.standard &&
              surface.elevation == AppElevation.level2,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_sceneKey),
        matchesGoldenFile('goldens/d13_live_depth_$variant.png'),
      );
    });
  }
}

void _noop() {}

void _select(String _) {}
