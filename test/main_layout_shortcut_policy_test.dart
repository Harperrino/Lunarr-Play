import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/shell/main_layout_screen.dart';

void main() {
  test('catalogue tabs do not expose Player A shortcuts', () {
    final policy = playerShortcutScopePolicy(
      playerSurfaceVisible: false,
      seekablePlayback: false,
    );

    expect(policy.enabled, isFalse);
    expect(policy.channelNavigationEnabled, isFalse);
  });

  test('visible Live media keeps channel navigation', () {
    final policy = playerShortcutScopePolicy(
      playerSurfaceVisible: true,
      seekablePlayback: false,
    );

    expect(policy.enabled, isTrue);
    expect(policy.channelNavigationEnabled, isTrue);
  });

  test('seekable playback keeps controls but not channel arrows', () {
    final policy = playerShortcutScopePolicy(
      playerSurfaceVisible: true,
      seekablePlayback: true,
    );

    expect(policy.enabled, isTrue);
    expect(policy.channelNavigationEnabled, isFalse);
  });
}
