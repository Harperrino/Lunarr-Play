import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/shell_tab_labels.dart';
import 'package:m3uxtream_player/app/shell/shell_tabs.dart';

void main() {
  group('shell tab catalog', () {
    test('keeps stable numeric identities and catalog order', () {
      expect(shellLiveTabIndex, 0);
      expect(shellPlaylistsTabIndex, 1);
      expect(shellEpgTabIndex, 2);
      expect(shellVodTabIndex, 3);
      expect(shellSeriesTabIndex, 4);
      expect(shellSettingsTabIndex, 5);
      expect(shellDiagnosticsTabIndex, 6);
      expect(shellFavoritesTabIndex, 7);
      expect(shellMediaLibraryTabIndex, 8);
      expect(shellTabSpecs.map((tab) => tab.index), [
        0,
        8,
        7,
        1,
        2,
        3,
        4,
        6,
        5,
      ]);
    });

    test('keeps playlists visible and settings as the final visible item', () {
      for (final debugModeEnabled in [false, true]) {
        final tabs = shellVisibleTabs(debugModeEnabled: debugModeEnabled);

        expect(tabs.any((tab) => tab.index == shellPlaylistsTabIndex), isTrue);
        expect(tabs.any((tab) => tab.index == shellFavoritesTabIndex), isTrue);
        expect(
          tabs.any((tab) => tab.index == shellMediaLibraryTabIndex),
          isTrue,
        );
        expect(tabs.last.index, shellSettingsTabIndex);
      }
    });

    test('hides diagnostics when debug mode is off', () {
      final tabs = shellVisibleTabs(debugModeEnabled: false);

      expect(tabs.any((tab) => tab.index == shellDiagnosticsTabIndex), isFalse);
      expect(tabs.any((tab) => tab.index == shellSettingsTabIndex), isTrue);
    });

    test('shows diagnostics when debug mode is on', () {
      final tabs = shellVisibleTabs(debugModeEnabled: true);

      expect(tabs.any((tab) => tab.index == shellDiagnosticsTabIndex), isTrue);
    });

    test('returns diagnostics header copy only when visible', () {
      expect(
        shellHeaderTitle(shellDiagnosticsTabIndex, debugModeEnabled: false),
        'Settings',
      );

      expect(
        shellHeaderTitle(shellDiagnosticsTabIndex, debugModeEnabled: true),
        'Diagnostics / Logs',
      );
    });

    test('fallback tab stays on settings', () {
      expect(shellFallbackTabIndex(), shellSettingsTabIndex);
    });

    test('exposes the Material 3 shell geometry tokens', () {
      expect(shellSidebarWidth(false), shellSidebarCollapsedWidth);
      expect(shellSidebarWidth(true), shellSidebarExpandedWidth);
      expect(shellSidebarCollapsedWidth, 80);
      expect(shellSidebarExpandedWidth, 256);
      expect(shellSidebarNavigationRowHeight, 48);
      expect(shellSidebarSelectedRadius, 24);
    });
  });
}
