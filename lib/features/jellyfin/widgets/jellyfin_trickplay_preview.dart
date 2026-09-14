import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/features/jellyfin/api/jellyfin_api_client.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_playback_assist.dart';
import 'package:m3uxtream_player/features/jellyfin/widgets/jellyfin_formatting.dart';

const int _maximumDecodedTileWidth = 1920;
const int _maximumDecodedTileHeight = 1080;

typedef JellyfinTrickplayImageDecoder = Future<ui.Image?> Function(
  Uint8List bytes,
  JellyfinTrickplayResolution resolution,
);

Future<ui.Image?> decodeJellyfinTrickplayImage(
  Uint8List bytes,
  JellyfinTrickplayResolution resolution,
) async {
  ui.Codec? codec;
  try {
    final sheetWidth = resolution.width * resolution.tileColumns;
    final sheetHeight = resolution.height * resolution.tileRows;
    final scale = math.min(
      1.0,
      math.min(
        _maximumDecodedTileWidth / sheetWidth,
        _maximumDecodedTileHeight / sheetHeight,
      ),
    );
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: math.max(1, (sheetWidth * scale).round()),
      targetHeight: math.max(1, (sheetHeight * scale).round()),
      allowUpscaling: false,
    );
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  } finally {
    codec?.dispose();
  }
}

class JellyfinTrickplayPreview extends StatefulWidget {
  const JellyfinTrickplayPreview({
    super.key,
    required this.apiClient,
    required this.connection,
    required this.itemId,
    required this.manifest,
    required this.position,
    this.imageDecoder = decodeJellyfinTrickplayImage,
  });

  final JellyfinApiClient apiClient;
  final JellyfinConnection connection;
  final String itemId;
  final JellyfinTrickplayManifest manifest;
  final Duration position;
  final JellyfinTrickplayImageDecoder imageDecoder;

  @override
  State<JellyfinTrickplayPreview> createState() =>
      _JellyfinTrickplayPreviewState();
}

class _JellyfinTrickplayPreviewState extends State<JellyfinTrickplayPreview> {
  late final JellyfinTrickplayTileCache<ui.Image> _cache =
      JellyfinTrickplayTileCache<ui.Image>(
        onEvicted: (image) => image.dispose(),
      );
  final Map<String, Future<ui.Image?>> _pendingLoads = {};
  ui.Image? _image;
  String? _loadedKey;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(JellyfinTrickplayPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.manifest.mediaSourceId != widget.manifest.mediaSourceId ||
        oldWidget.connection.baseUrl != widget.connection.baseUrl ||
        oldWidget.connection.serverId != widget.connection.serverId ||
        oldWidget.connection.userId != widget.connection.userId ||
        oldWidget.apiClient != widget.apiClient ||
        oldWidget.imageDecoder != widget.imageDecoder) {
      _requestGeneration++;
      _image = null;
      _loadedKey = null;
      _cache.clear();
      _pendingLoads.clear();
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = _currentRequest();
    if (request == null) return;
    if (_loadedKey == request.key && _image != null) return;
    final cached = _cache.get(request.key);
    if (cached != null) {
      if (mounted && request.key == _currentRequest()?.key) {
        setState(() {
          _loadedKey = request.key;
          _image = cached;
        });
      }
      return;
    }
    if (_pendingLoads.containsKey(request.key)) return;

    final generation = _requestGeneration;
    final pending = _fetchAndDecode(request);
    _pendingLoads[request.key] = pending;
    final image = await pending;
    if (identical(_pendingLoads[request.key], pending)) {
      _pendingLoads.remove(request.key);
    }
    if (image == null) return;
    if (!mounted ||
        generation != _requestGeneration ||
        request.key != _currentRequest()?.key) {
      image.dispose();
      return;
    }
    _cache.put(request.key, image);
    setState(() {
      _loadedKey = request.key;
      _image = image;
    });
  }

  Future<ui.Image?> _fetchAndDecode(_JellyfinTrickplayRequest request) async {
    final bytes = await widget.apiClient.fetchTrickplayTile(
      widget.connection,
      itemId: widget.itemId,
      mediaSourceId: widget.manifest.mediaSourceId,
      width: request.resolution.width,
      index: request.frame.tileIndex,
    );
    if (bytes == null) return null;
    return widget.imageDecoder(bytes, request.resolution);
  }

  _JellyfinTrickplayRequest? _currentRequest() {
    final resolution = widget.manifest.bestResolution();
    final frame = resolution == null
        ? null
        : JellyfinTrickplayFrame.calculate(resolution, widget.position);
    if (resolution == null || frame == null) return null;
    return _JellyfinTrickplayRequest(
      key:
          '${widget.itemId}:${widget.manifest.mediaSourceId}:'
          '${resolution.width}x${resolution.height}:'
          '${resolution.tileColumns}x${resolution.tileRows}:'
          '${resolution.interval.inMilliseconds}:${frame.tileIndex}',
      resolution: resolution,
      frame: frame,
    );
  }

  @override
  void dispose() {
    _requestGeneration++;
    _image = null;
    _loadedKey = null;
    _cache.clear();
    _pendingLoads.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = _currentRequest();
    final image = _image;
    if (request == null || image == null || _loadedKey != request.key) {
      return const SizedBox(height: 2);
    }
    final resolution = request.resolution;
    final frame = request.frame;
    final scale = math.min(1.0, 240 / resolution.width);
    final frameWidth = resolution.width * scale;
    final frameHeight = resolution.height * scale;
    return Center(
      child: DecoratedBox(
        key: const ValueKey('jellyfin-trickplay-preview'),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black54)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              SizedBox(
                width: frameWidth,
                height: frameHeight,
                child: ClipRect(
                  child: RepaintBoundary(
                    key: const ValueKey('jellyfin-trickplay-frame'),
                    child: CustomPaint(
                      painter: JellyfinTrickplayTilePainter(
                        image: image,
                        tileColumns: resolution.tileColumns,
                        tileRows: resolution.tileRows,
                        column: frame.column,
                        row: frame.row,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: frameWidth,
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  jellyfinFormatDuration(widget.position),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JellyfinTrickplayTilePainter extends CustomPainter {
  const JellyfinTrickplayTilePainter({
    required this.image,
    required this.tileColumns,
    required this.tileRows,
    required this.column,
    required this.row,
  });

  final ui.Image image;
  final int tileColumns;
  final int tileRows;
  final int column;
  final int row;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || tileColumns <= 0 || tileRows <= 0) return;
    final cellWidth = image.width / tileColumns;
    final cellHeight = image.height / tileRows;
    final source = Rect.fromLTWH(
      column * cellWidth,
      row * cellHeight,
      cellWidth,
      cellHeight,
    );
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(JellyfinTrickplayTilePainter oldDelegate) =>
      !identical(image, oldDelegate.image) ||
      tileColumns != oldDelegate.tileColumns ||
      tileRows != oldDelegate.tileRows ||
      column != oldDelegate.column ||
      row != oldDelegate.row;
}

class _JellyfinTrickplayRequest {
  const _JellyfinTrickplayRequest({
    required this.key,
    required this.resolution,
    required this.frame,
  });

  final String key;
  final JellyfinTrickplayResolution resolution;
  final JellyfinTrickplayFrame frame;
}
