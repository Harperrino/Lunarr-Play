import 'dart:collection';

enum JellyfinMediaSegmentType {
  intro,
  outro,
  recap,
  preview,
  commercial,
  unknown;

  static JellyfinMediaSegmentType fromJson(Object? value) {
    final normalized = value?.toString().toLowerCase();
    return values.where((type) => type.name == normalized).firstOrNull ??
        unknown;
  }
}

class JellyfinMediaSegment {
  const JellyfinMediaSegment({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
  });

  final String id;
  final JellyfinMediaSegmentType type;
  final Duration start;
  final Duration end;

  bool contains(Duration position) => position >= start && position < end;

  static JellyfinMediaSegment? fromJson(Map<String, dynamic> json) {
    final startTicks = (json['StartTicks'] as num?)?.toInt();
    final endTicks = (json['EndTicks'] as num?)?.toInt();
    if (startTicks == null ||
        endTicks == null ||
        startTicks < 0 ||
        endTicks <= startTicks) {
      return null;
    }
    final type = JellyfinMediaSegmentType.fromJson(json['Type']);
    return JellyfinMediaSegment(
      id: json['Id']?.toString() ?? '$startTicks-$endTicks-${type.name}',
      type: type,
      start: Duration(microseconds: startTicks ~/ 10),
      end: Duration(microseconds: endTicks ~/ 10),
    );
  }
}

class JellyfinTrickplayResolution {
  const JellyfinTrickplayResolution({
    required this.width,
    required this.height,
    required this.tileColumns,
    required this.tileRows,
    required this.thumbnailCount,
    required this.interval,
  });

  final int width;
  final int height;
  final int tileColumns;
  final int tileRows;
  final int thumbnailCount;
  final Duration interval;

  int get framesPerTile => tileColumns * tileRows;

  static JellyfinTrickplayResolution? fromJson(Map<String, dynamic> json) {
    final width = (json['Width'] as num?)?.toInt();
    final height = (json['Height'] as num?)?.toInt();
    final columns = (json['TileWidth'] as num?)?.toInt();
    final rows = (json['TileHeight'] as num?)?.toInt();
    final count = (json['ThumbnailCount'] as num?)?.toInt();
    final interval = (json['Interval'] as num?)?.toInt();
    if ([
      width,
      height,
      columns,
      rows,
      count,
      interval,
    ].any((value) => value == null || value <= 0)) {
      return null;
    }
    return JellyfinTrickplayResolution(
      width: width!,
      height: height!,
      tileColumns: columns!,
      tileRows: rows!,
      thumbnailCount: count!,
      interval: Duration(milliseconds: interval!),
    );
  }
}

class JellyfinTrickplayManifest {
  const JellyfinTrickplayManifest({
    required this.mediaSourceId,
    required this.resolutions,
  });

  final String mediaSourceId;
  final List<JellyfinTrickplayResolution> resolutions;

  JellyfinTrickplayResolution? bestResolution({int targetWidth = 240}) {
    if (resolutions.isEmpty) return null;
    final sorted = [...resolutions]..sort((a, b) => a.width.compareTo(b.width));
    return sorted.where((entry) => entry.width >= targetWidth).firstOrNull ??
        sorted.last;
  }
}

class JellyfinTrickplayFrame {
  const JellyfinTrickplayFrame({
    required this.tileIndex,
    required this.column,
    required this.row,
    required this.timestamp,
  });

  final int tileIndex;
  final int column;
  final int row;
  final Duration timestamp;

  static JellyfinTrickplayFrame? calculate(
    JellyfinTrickplayResolution resolution,
    Duration position,
  ) {
    final intervalMs = resolution.interval.inMilliseconds;
    if (intervalMs <= 0 || resolution.framesPerTile <= 0) return null;
    final frame = (position.inMilliseconds ~/ intervalMs).clamp(
      0,
      resolution.thumbnailCount - 1,
    );
    final cell = frame % resolution.framesPerTile;
    return JellyfinTrickplayFrame(
      tileIndex: frame ~/ resolution.framesPerTile,
      column: cell % resolution.tileColumns,
      row: cell ~/ resolution.tileColumns,
      timestamp: Duration(milliseconds: frame * intervalMs),
    );
  }
}

class JellyfinTrickplayTileCache<T> {
  JellyfinTrickplayTileCache({this.capacity = 2, this.onEvicted})
    : assert(capacity > 0);

  final int capacity;
  final void Function(T value)? onEvicted;
  final LinkedHashMap<String, T> _entries = LinkedHashMap();

  T? get(String key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  void put(String key, T value) {
    final previous = _entries.remove(key);
    if (previous != null && !identical(previous, value)) {
      onEvicted?.call(previous);
    }
    _entries[key] = value;
    while (_entries.length > capacity) {
      final evicted = _entries.remove(_entries.keys.first);
      if (evicted != null) onEvicted?.call(evicted);
    }
  }

  void clear() {
    final values = _entries.values.toList(growable: false);
    _entries.clear();
    for (final value in values) {
      onEvicted?.call(value);
    }
  }
}
