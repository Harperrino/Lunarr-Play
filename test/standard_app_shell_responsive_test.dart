import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/standard_app_shell.dart';
import 'package:m3uxtream_player/app/shell/shell_command_area.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';

Widget _shell({required double textScale}) => ProviderScope(
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: StandardAppShell(
          activeIndex: shellLiveTabIndex,
          debugModeEnabled: false,
          sidebarExpanded: false,
          onSidebarToggle: () {},
          onSidebarTap: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'standard shell adapts at content-width breakpoints and 200 percent text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final gutters = <double, double>{719: 12, 720: 16, 1199: 16, 1200: 24};

      for (final textScale in [1.0, 2.0]) {
        for (final entry in gutters.entries) {
          tester.view.physicalSize = Size(
            entry.key + shellSidebarCollapsedWidth,
            900,
          );
          tester.view.devicePixelRatio = 1;

          await tester.pumpWidget(_shell(textScale: textScale));
          await tester.pumpAndSettle();

          // Global search is owned by the shared Material 3 window top bar.
          expect(find.byType(TextField), findsNothing);
          final padding = tester.widget<Padding>(
            find.ancestor(
              of: find.byType(ShellCommandArea),
              matching: find.byType(Padding),
            ),
          );
          expect(padding.padding, EdgeInsets.all(entry.value));
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
