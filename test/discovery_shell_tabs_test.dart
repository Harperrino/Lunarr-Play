import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';

void main() {
  test('Home receives a new stable ID without shifting existing IDs', () {
    expect(shellLiveTabIndex, 0);
    expect(shellSettingsTabIndex, 5);
    expect(shellJellyfinTabIndex, 9);
    expect(shellHomeTabIndex, 10);
    expect(shellTabSpecs.first.kind, ShellTabKind.home);
  });

  test('new installs prefer visible Home', () {
    expect(
      shellStartupTabIndex(preferHome: true, debugModeEnabled: false),
      shellHomeTabIndex,
    );
  });

  test('hidden Home falls back to Live and then Settings', () {
    expect(
      shellStartupTabIndex(
        preferHome: true,
        debugModeEnabled: false,
        hiddenKinds: const <ShellTabKind>{ShellTabKind.home},
      ),
      shellLiveTabIndex,
    );
    expect(
      shellStartupTabIndex(
        preferHome: true,
        debugModeEnabled: false,
        hiddenKinds: const <ShellTabKind>{ShellTabKind.home, ShellTabKind.live},
      ),
      shellSettingsTabIndex,
    );
  });

  test(
    'an explicitly selected but hidden Live target falls back to Settings',
    () {
      expect(
        shellStartupTabIndex(
          preferHome: false,
          debugModeEnabled: false,
          hiddenKinds: const <ShellTabKind>{ShellTabKind.live},
        ),
        shellSettingsTabIndex,
      );
    },
  );
}
