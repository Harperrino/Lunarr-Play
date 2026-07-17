import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';
import 'package:m3uxtream_player/features/search/widgets/global_search_field.dart';
import 'package:m3uxtream_player/shared/theme/app_color_roles.dart';
import 'package:m3uxtream_player/shared/theme/app_component_themes.dart';
import 'package:m3uxtream_player/shared/theme/app_elevation.dart';
import 'package:m3uxtream_player/shared/theme/app_status_colors.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_pane_toggle_button.dart';
import 'package:m3uxtream_player/shared/widgets/m3_slots.dart';
import 'package:m3uxtream_player/shared/widgets/m3_tab_shelf.dart';

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() >= second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void main() {
  test(
    'D11 accent hues use generated roles with stable semantic status colors',
    () {
      for (final hue in [0, 30, 60, 90, 120, 170, 210, 270, 320]) {
        final scheme = AppColorRoles.darkSchemeFor(
          accentHue: hue.toDouble(),
          surfaceTone: 0.5,
        );

        expect(scheme.brightness, Brightness.dark);
        expect(
          _contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(scheme.error, AppColorRoles.error);
        expect(scheme.errorContainer, AppColorRoles.errorContainer);
      }
    },
  );

  test(
    'switch colors come from the shared theme and hide selected outlines',
    () {
      final colors = AppColorRoles.darkSchemeFor(
        accentHue: 320,
        surfaceTone: 0.5,
      );
      final status = AppStatusColors.dark;
      final switches = AppComponentThemes.switchControl(colors, status);

      expect(
        switches.trackColor!.resolve({WidgetState.selected}),
        colors.primary,
      );
      expect(
        switches.thumbColor!.resolve({WidgetState.selected}),
        colors.onPrimary,
      );
      expect(
        switches.trackOutlineColor!.resolve({WidgetState.selected}),
        Colors.transparent,
      );
      expect(
        switches.trackOutlineColor!.resolve({
          WidgetState.selected,
          WidgetState.focused,
        }),
        status.focus,
      );
      expect(
        switches.trackColor!.resolve(<WidgetState>{}),
        colors.surfaceContainerHighest,
      );
    },
  );

  testWidgets('search bar owns one 56-dp Material contour', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: AppColorRoles.darkScheme,
            extensions: const <ThemeExtension<dynamic>>[AppStatusColors.dark],
          ),
          home: const Scaffold(
            body: SizedBox(width: 640, child: GlobalSearchField(width: 720)),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.byType(AppSurface), findsNothing);
    expect(tester.getSize(find.byType(SearchBar)), const Size(640, 56));
    final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(searchBar.side!.resolve(<WidgetState>{}), BorderSide.none);
    expect(searchBar.side!.resolve({WidgetState.focused})!.width, 2);
  });

  testWidgets('search preserves provider sync, editing and clear semantics', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const Scaffold(body: GlobalSearchField())),
      ),
    );

    final editable = find.byType(EditableText);
    await tester.enterText(editable, 'cinema');
    await tester.pump();
    expect(container.read(globalSearchQueryProvider), 'cinema');
    expect(find.byTooltip('Clear search'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(container.read(globalSearchQueryProvider), isEmpty);

    container.read(globalSearchQueryProvider.notifier).state = 'remote';
    await tester.pump();
    expect(tester.widget<EditableText>(editable).controller.text, 'remote');
  });

  testWidgets('shell search widths stay bounded and do not overlap the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (width, expectedSearchWidth) in [
      (900.0, 540.0),
      (1200.0, 624.0),
      (1600.0, 720.0),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: ShellCommandArea(
                  title: 'Library',
                  supportingText: 'Browse the active catalogue.',
                  search: const GlobalSearchField(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final searchRect = tester.getRect(find.byKey(ShellCommandArea.searchKey));
      final titleRect = tester.getRect(find.byKey(ShellCommandArea.titleKey));
      expect(searchRect.width, closeTo(expectedSearchWidth, 0.01));
      expect(searchRect.height, 56);
      expect(searchRect.overlaps(titleRect), isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('pane toggle keeps reciprocal icon, target and semantics', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: M3PaneToggleButton(
            paneLabel: 'Sidebar',
            expanded: true,
            onPressed: () => activations++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(M3PaneToggleButton), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(M3ActionSlot)), const Size(48, 48));
    expect(find.byTooltip('Collapse Sidebar'), findsOneWidget);
    expect(find.bySemanticsLabel('Collapse Sidebar'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse Sidebar'));
    expect(activations, 1);
  });

  testWidgets('elevation ladder is exact and tab shelf owns level one', (
    tester,
  ) async {
    expect(AppElevation.level0, 0);
    expect(AppElevation.level1, 1);
    expect(AppElevation.level2, 3);
    expect(AppElevation.level3, 6);
    expect(AppElevation.level4, 8);
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.hovered,
      }),
      AppElevation.level1,
    );
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.dragged,
      }),
      AppElevation.level1,
    );
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.focused,
      }, behavior: AppElevationBehavior.elevatedCard),
      AppElevation.level1,
    );
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.pressed,
      }, behavior: AppElevationBehavior.elevatedCard),
      AppElevation.level1,
    );
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.disabled,
        WidgetState.hovered,
      }, behavior: AppElevationBehavior.elevatedCard),
      AppElevation.level1,
    );
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.hovered,
      }, behavior: AppElevationBehavior.elevatedCard),
      AppElevation.level2,
    );
    expect(
      AppElevation.resolveForStates(AppElevation.level1, const <WidgetState>{
        WidgetState.dragged,
      }, behavior: AppElevationBehavior.elevatedCard),
      AppElevation.level4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: M3TabShelf(child: const Text('Tabs'))),
      ),
    );
    final surface = tester.widget<AppSurface>(find.byType(AppSurface));
    expect(surface.elevation, AppElevation.level1);
  });
}
