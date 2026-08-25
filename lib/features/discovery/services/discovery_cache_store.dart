import 'dart:convert';
import 'dart:io';

import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

abstract interface class DiscoveryCacheStore {
  Future<DiscoveryHomeFeed?> read(String key);

  Future<void> write(String key, DiscoveryHomeFeed feed);
}

class InMemoryDiscoveryCacheStore implements DiscoveryCacheStore {
  final Map<String, DiscoveryHomeFeed> _values = <String, DiscoveryHomeFeed>{};

  @override
  Future<DiscoveryHomeFeed?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, DiscoveryHomeFeed feed) async {
    _values[key] = feed;
  }
}

class FileDiscoveryCacheStore implements DiscoveryCacheStore {
  FileDiscoveryCacheStore({
    Future<Directory> Function()? directoryProvider,
    this.maxBytes = 2 * 1024 * 1024,
    this.maxEntries = 8,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const _fileName = 'discovery_cache.json';

  final Future<Directory> Function() _directoryProvider;
  final int maxBytes;
  final int maxEntries;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<DiscoveryHomeFeed?> read(String key) => _serialize(() async {
    final entries = await _readEntriesUnlocked();
    final value = entries[key];
    if (value is! Map) return null;
    try {
      return DiscoveryHomeFeed.fromJson(value['feed']);
    } catch (_) {
      return null;
    }
  });

  @override
  Future<void> write(String key, DiscoveryHomeFeed feed) =>
      _serialize(() async {
        final entries = await _readEntriesUnlocked();
        entries[key] = <String, Object?>{
          'storedAt': DateTime.now().toUtc().toIso8601String(),
          'feed': feed.toJson(),
        };
        final ordered = entries.entries.toList(growable: false)
          ..sort((left, right) {
            final leftAt = _storedAt(left.value);
            final rightAt = _storedAt(right.value);
            return rightAt.compareTo(leftAt);
          });
        final limited = <String, Object?>{
          for (final entry in ordered.take(maxEntries)) entry.key: entry.value,
        };
        var encoded = utf8.encode(
          jsonEncode(<String, Object?>{'version': 1, 'entries': limited}),
        );
        while (encoded.length > maxBytes && limited.length > 1) {
          limited.remove(limited.keys.last);
          encoded = utf8.encode(
            jsonEncode(<String, Object?>{'version': 1, 'entries': limited}),
          );
        }
        if (encoded.length > maxBytes) return;
        await _atomicWrite(encoded);
      });

  Future<Map<String, Object?>> _readEntriesUnlocked() async {
    final file = await _file();
    if (!await file.exists()) return <String, Object?>{};
    try {
      if (await file.length() > maxBytes) return <String, Object?>{};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['version'] != 1) {
        return <String, Object?>{};
      }
      final raw = decoded['entries'];
      if (raw is! Map) return <String, Object?>{};
      return <String, Object?>{
        for (final entry in raw.entries)
          if (entry.key is String) entry.key as String: entry.value,
      };
    } catch (_) {
      return <String, Object?>{};
    }
  }

  DateTime _storedAt(Object? value) {
    if (value is! Map) return DateTime(1970);
    return DateTime.tryParse(value['storedAt']?.toString() ?? '') ??
        DateTime(1970);
  }

  Future<void> _atomicWrite(List<int> bytes) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.backup');
    await temporary.writeAsBytes(bytes, flush: true);
    var movedExisting = false;
    try {
      if (await backup.exists()) await backup.delete();
      if (await file.exists()) {
        await file.rename(backup.path);
        movedExisting = true;
      }
      await temporary.rename(file.path);
      if (movedExisting && await backup.exists()) await backup.delete();
    } catch (_) {
      if (movedExisting && !await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completion = _operationTail.then((_) => operation());
    _operationTail = completion.then<void>((_) {}, onError: (_, _) {});
    return completion;
  }

  Future<File> _file() async {
    final directory = await _directoryProvider();
    return File(path.join(directory.path, _fileName));
  }
}
