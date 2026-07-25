import 'dart:io';

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/app/bootstrap/desktop_window_placement.dart';

void main() {
  test('window placement policy validates, clamps and centers sizes', () {
    expect(
      DesktopWindowPlacementPolicy.resolveSize(
        storedSize: null,
        workAreaSize: const Size(1920, 1080),
      ),
      const Size(1440, 900),
    );
    expect(
      DesktopWindowPlacementPolicy.resolveSize(
        storedSize: const Size(100, 100),
        workAreaSize: const Size(1920, 1080),
      ),
      const Size(1440, 900),
    );
    expect(
      DesktopWindowPlacementPolicy.resolveSize(
        storedSize: const Size(2200, 1300),
        workAreaSize: const Size(1920, 1080),
      ),
      const Size(1920, 1080),
    );
    expect(
      DesktopWindowPlacementPolicy.resolveSize(
        storedSize: const Size(1440, 900),
        workAreaSize: const Size(1280, 720),
      ),
      const Size(1280, 720),
    );
    expect(
      DesktopWindowPlacementPolicy.centeredPosition(
        windowSize: const Size(1200, 800),
        workAreaPosition: const Offset(100, 40),
        workAreaSize: const Size(1600, 1000),
      ),
      const Offset(300, 140),
    );
  });

  test('placement store persists only the versioned normal size', () async {
    final directory = await Directory.systemTemp.createTemp(
      'm3uxtream-window-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/placement.json');
    final store = DesktopWindowPlacementStore(file: file);

    expect(await store.load(), isNull);
    await store.save(const Size(1234, 777));
    expect(await store.load(), const Size(1234, 777));

    await file.writeAsString('{"version": 999, "width": 1600, "height": 900}');
    expect(await store.load(), isNull);
    await file.writeAsString('{"version": 1, "width": "bad", "height": 900}');
    expect(await store.load(), isNull);
  });

  test(
    'resize controller ignores immersive and non-normal window states',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'm3uxtream-window-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = DesktopWindowPlacementStore(
        file: File('${directory.path}/placement.json'),
      );
      var maximized = false;
      var minimized = false;
      var fullscreen = false;
      var size = const Size(1200, 800);
      final controller = DesktopWindowPlacementController(
        store: store,
        isMaximized: () async => maximized,
        isMinimized: () async => minimized,
        isFullScreen: () async => fullscreen,
        getSize: () async => size,
      );
      addTearDown(controller.dispose);

      controller.onWindowResize();
      await Future<void>.delayed(Duration.zero);
      await controller.flush();
      expect(await store.load(), const Size(1200, 800));

      size = const Size(1400, 850);
      maximized = true;
      controller.onWindowResize();
      await controller.flush();
      expect(await store.load(), const Size(1200, 800));

      maximized = false;
      fullscreen = true;
      controller.onWindowResize();
      await controller.flush();
      expect(await store.load(), const Size(1200, 800));

      controller.onWindowResize(immersive: true);
      await controller.flush();
      expect(await store.load(), const Size(1200, 800));

      fullscreen = false;
      minimized = true;
      controller.onWindowResize();
      await controller.flush();
      expect(await store.load(), const Size(1200, 800));
    },
  );
}
