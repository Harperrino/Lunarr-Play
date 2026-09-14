import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_assist.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_trickplay_preview.dart';

const _connection = JellyfinConnection(
  baseUrl: 'http://server:8096',
  serverId: 'server-id',
  serverVersion: '10.10.3',
  userId: 'user-id',
  username: 'alice',
  accessToken: 'token',
  deviceId: 'device-id',
);

const _resolution = JellyfinTrickplayResolution(
  width: 20,
  height: 10,
  tileColumns: 2,
  tileRows: 2,
  thumbnailCount: 8,
  interval: Duration(seconds: 10),
);

const _manifest = JellyfinTrickplayManifest(
  mediaSourceId: 'source-id',
  resolutions: [_resolution],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crops the requested cell across rows and tile boundaries', (
    tester,
  ) async {
    final firstTile = (await tester.runAsync(
      () => _spriteImage(const [
        Color(0xFFFF0000),
        Color(0xFF00FF00),
        Color(0xFF0000FF),
        Color(0xFFFFFF00),
      ]),
    ))!;
    final secondTile = (await tester.runAsync(
      () => _spriteImage(const [
        Color(0xFF00FFFF),
        Color(0xFFFF00FF),
        Color(0xFFFF8000),
        Color(0xFFFFFFFF),
      ]),
    ))!;
    final requests = <int, int>{};
    final client = _TileApiClient(({required width, required index}) async {
      requests.update(index, (count) => count + 1, ifAbsent: () => 1);
      return Uint8List.fromList([index]);
    });

    Future<ui.Image?> decoder(
      Uint8List bytes,
      JellyfinTrickplayResolution _,
    ) async => bytes.single == 0 ? firstTile : secondTile;

    Future<void> expectFrame(Duration position, Color expected) async {
      await tester.pumpWidget(_host(client, position, imageDecoder: decoder));
      await tester.pumpAndSettle();
      expect(await _renderedFrameColor(tester), expected);
    }

    await expectFrame(Duration.zero, const Color(0xFFFF0000));
    await expectFrame(const Duration(seconds: 10), const Color(0xFF00FF00));
    await expectFrame(const Duration(seconds: 20), const Color(0xFF0000FF));
    await expectFrame(const Duration(seconds: 30), const Color(0xFFFFFF00));
    await expectFrame(const Duration(seconds: 40), const Color(0xFF00FFFF));

    expect(requests, {0: 1, 1: 1});
  });

  testWidgets('deduplicates pending requests and never paints a stale tile', (
    tester,
  ) async {
    final staleTile = (await tester.runAsync(
      () => _spriteImage(List<Color>.filled(4, const Color(0xFFFF0000))),
    ))!;
    final currentTile = (await tester.runAsync(
      () => _spriteImage(List<Color>.filled(4, const Color(0xFF0000FF))),
    ))!;
    final responses = <int, Completer<Uint8List?>>{
      0: Completer<Uint8List?>(),
      1: Completer<Uint8List?>(),
    };
    final requests = <int, int>{};
    final client = _TileApiClient(({required width, required index}) {
      requests.update(index, (count) => count + 1, ifAbsent: () => 1);
      return responses[index]!.future;
    });

    Future<ui.Image?> decoder(
      Uint8List bytes,
      JellyfinTrickplayResolution _,
    ) async => bytes.single == 0 ? staleTile : currentTile;

    await tester.pumpWidget(
      _host(client, Duration.zero, imageDecoder: decoder),
    );
    await tester.pump();
    await tester.pumpWidget(
      _host(client, const Duration(seconds: 10), imageDecoder: decoder),
    );
    await tester.pump();
    await tester.pumpWidget(
      _host(client, const Duration(seconds: 20), imageDecoder: decoder),
    );
    await tester.pump();
    expect(requests, {0: 1});

    await tester.pumpWidget(
      _host(client, const Duration(seconds: 40), imageDecoder: decoder),
    );
    await tester.pump();
    expect(requests, {0: 1, 1: 1});

    responses[0]!.complete(Uint8List.fromList([0]));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('jellyfin-trickplay-preview')),
      findsNothing,
    );

    responses[1]!.complete(Uint8List.fromList([1]));
    await tester.pumpAndSettle();
    expect(await _renderedFrameColor(tester), const Color(0xFF0000FF));
    expect(requests, {0: 1, 1: 1});
  });

  for (final failure in <({String name, Uint8List? bytes, bool decoderCalled})>[
    (
      name: 'invalid image bytes',
      bytes: Uint8List.fromList([1, 2, 3]),
      decoderCalled: true,
    ),
    (name: 'missing tile', bytes: null, decoderCalled: false),
  ]) {
    testWidgets('${failure.name} omits the preview surface', (tester) async {
      var decoderCalled = false;
      final client = _TileApiClient(
        ({required width, required index}) async => failure.bytes,
      );

      await tester.pumpWidget(
        _host(
          client,
          Duration.zero,
          imageDecoder: (_, _) async {
            decoderCalled = true;
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('jellyfin-trickplay-preview')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('jellyfin-trickplay-frame')),
        findsNothing,
      );
      expect(decoderCalled, failure.decoderCalled);
    });
  }

  testWidgets('production decoder rejects malformed image bytes', (
    tester,
  ) async {
    final image = await tester.runAsync(
      () => decodeJellyfinTrickplayImage(
        Uint8List.fromList([1, 2, 3]),
        _resolution,
      ),
    );

    expect(image, isNull);
  });
}

Widget _host(
  JellyfinApiClient client,
  Duration position, {
  JellyfinTrickplayImageDecoder imageDecoder = decodeJellyfinTrickplayImage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        child: JellyfinTrickplayPreview(
          apiClient: client,
          connection: _connection,
          itemId: 'episode-id',
          manifest: _manifest,
          position: position,
          imageDecoder: imageDecoder,
        ),
      ),
    ),
  );
}

typedef _TileLoader = Future<Uint8List?> Function({
  required int width,
  required int index,
});

class _TileApiClient extends JellyfinApiClient {
  _TileApiClient(this.loader)
    : super(
        transport: MockClient(
          (_) async => throw StateError('Unexpected HTTP request.'),
        ),
      );

  final _TileLoader loader;

  @override
  Future<Uint8List?> fetchTrickplayTile(
    JellyfinConnection connection, {
    required String itemId,
    required String mediaSourceId,
    required int width,
    required int index,
  }) => loader(width: width, index: index);
}

Future<ui.Image> _spriteImage(List<Color> colors) async {
  assert(colors.length == 4);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var index = 0; index < colors.length; index++) {
    canvas.drawRect(
      Rect.fromLTWH((index % 2) * 20, (index ~/ 2) * 10, 20, 10),
      Paint()..color = colors[index],
    );
  }
  return recorder.endRecording().toImage(40, 20);
}

Future<Color> _renderedFrameColor(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('jellyfin-trickplay-frame'));
  expect(finder, findsOneWidget);
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Could not read rendered preview.');
      final x = image.width ~/ 2;
      final y = image.height ~/ 2;
      final offset = (y * image.width + x) * 4;
      return Color.fromARGB(
        data.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}
