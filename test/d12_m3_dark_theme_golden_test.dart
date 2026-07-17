@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_navigation_item.dart';
import 'package:m3uxtream_player/shared/widgets/m3_tab_shelf.dart';
import 'package:m3uxtream_player/shared/widgets/media/media_poster_frame.dart';

const _sceneKey = ValueKey<String>('d12-m3-dark-theme-scene');

ColorScheme _schemeFor(String variant) => switch (variant) {
  'neutral' => ColorScheme.fromSeed(
    seedColor: Colors.grey,
    brightness: Brightness.dark,
  ),
  'yellow' => AppColorRoles.darkSchemeFor(accentHue: 60, surfaceTone: 0.5),
  'green' => AppColorRoles.darkSchemeFor(accentHue: 120, surfaceTone: 0.5),
  'blue' => AppColorRoles.darkSchemeFor(accentHue: 220, surfaceTone: 0.5),
  _ => throw ArgumentError.value(variant),
};

Widget _scene(ColorScheme colors) {
  final railTheme = NavigationRailThemeData(
    indicatorColor: colors.secondaryContainer,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    selectedIconTheme: IconThemeData(color: colors.onSecondaryContainer),
    unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
    selectedLabelTextStyle: TextStyle(color: colors.onSurface),
    unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
  );

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      navigationRailTheme: railTheme,
    ),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: _sceneKey,
          child: SizedBox(
            width: 720,
            height: 400,
            child: ColoredBox(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSurface(
                      level: AppSurfaceLevel.low,
                      elevation: 1,
                      width: 136,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
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
                          Builder(
                            builder: (context) => Text(
                              'Material 3 surface roles',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 12),
                          M3TabShelf(
                            child: const DefaultTabController(
                              length: 2,
                              child: TabBar(
                                tabs: [
                                  Tab(text: 'Movies'),
                                  Tab(text: 'Series'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 150,
                            height: 225,
                            child: MediaPosterFrame(
                              semanticLabel: 'Poster sample',
                              onActivate: _noop,
                              poster: ColoredBox(
                                color: colors.primaryContainer,
                                child: Icon(
                                  Icons.movie_creation_outlined,
                                  color: colors.onPrimaryContainer,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final variant in ['neutral']) {
    testWidgets('D12 $variant dark-theme surface scene', (tester) async {
      await tester.pumpWidget(_scene(_schemeFor(variant)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(_sceneKey),
        matchesGoldenFile('goldens/d12_m3_dark_theme_$variant.png'),
      );
    });
  }
}

void _noop() {}
