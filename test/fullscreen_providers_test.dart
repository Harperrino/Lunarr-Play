import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/providers/fullscreen_providers.dart';
import 'package:m3uxtream_player/core/services/fullscreen_toggle.dart';

void main() {
  group('resolveImmersiveLayout', () {
    test('is false when not desktop', () {
      expect(
        resolveImmersiveLayout(
          isDesktop: false,
          isWindowFullscreen: true,
          activeSidebarIndex: 0,
        ),
        isFalse,
      );
    });

    test('is false when desktop but not fullscreen', () {
      expect(
        resolveImmersiveLayout(
          isDesktop: true,
          isWindowFullscreen: false,
          activeSidebarIndex: 0,
        ),
        isFalse,
      );
    });

    test('is false when desktop fullscreen but not on Live tab', () {
      expect(
        resolveImmersiveLayout(
          isDesktop: true,
          isWindowFullscreen: true,
          activeSidebarIndex: 5,
        ),
        isFalse,
      );
    });

    test('is true only for desktop + fullscreen + Live tab', () {
      expect(
        resolveImmersiveLayout(
          isDesktop: true,
          isWindowFullscreen: true,
          activeSidebarIndex: 0,
        ),
        isTrue,
      );
    });
  });

  group('resolveFullscreenToggleTarget', () {
    test('enters fullscreen when OS reports windowed', () {
      expect(resolveFullscreenToggleTarget(actualOsFullscreen: false), isTrue);
    });

    test('exits fullscreen when OS reports fullscreen', () {
      expect(resolveFullscreenToggleTarget(actualOsFullscreen: true), isFalse);
    });
  });

  group('immersiveLayoutProvider', () {
    test('delegates to resolveImmersiveLayout via Riverpod wiring', () {
      final container = ProviderContainer(
        overrides: [
          isDesktopPlatformProvider.overrideWith((ref) => true),
          isFullscreenProvider.overrideWith((ref) => true),
          activeSidebarIndexProvider.overrideWith((ref) => 0),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(immersiveLayoutProvider), isTrue);
    });
  });
}
