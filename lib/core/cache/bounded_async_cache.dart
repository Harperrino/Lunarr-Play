import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Small LRU for deduplicated asynchronous reads with absolute TTLs.
class BoundedAsyncCache<K, V> {
  BoundedAsyncCache({
    required this.maxEntries,
    required this.ttl,
    DateTime Function()? now,
  }) : assert(maxEntries > 0),
       _now = now ?? DateTime.now;

  final int maxEntries;
  final Duration ttl;
  final DateTime Function() _now;
  final LinkedHashMap<K, _AsyncCacheEntry<V>> _entries =
      LinkedHashMap<K, _AsyncCacheEntry<V>>();

  @visibleForTesting
  int get length => _entries.length;

  Future<V> getOrLoad(K key, Future<V> Function() loader) {
    final current = _entries.remove(key);
    if (current != null && current.expiresAt.isAfter(_now())) {
      _entries[key] = current;
      return current.value;
    }

    final value = Future<V>.sync(loader);
    final entry = _AsyncCacheEntry<V>(value: value, expiresAt: _now().add(ttl));
    _entries[key] = entry;
    _trim();
    unawaited(
      value.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_entries[key], entry)) _entries.remove(key);
        },
      ),
    );
    return value;
  }

  void invalidate(K key) => _entries.remove(key);

  void invalidateWhere(bool Function(K key) predicate) {
    _entries.removeWhere((key, _) => predicate(key));
  }

  void clear() => _entries.clear();

  void _trim() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _AsyncCacheEntry<V> {
  const _AsyncCacheEntry({required this.value, required this.expiresAt});

  final Future<V> value;
  final DateTime expiresAt;
}
