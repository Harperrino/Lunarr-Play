import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Synchronous bounded LRU for expensive, pure UI projections.
class BoundedValueCache<K, V> {
  BoundedValueCache({required this.maxEntries}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  @visibleForTesting
  int get length => _entries.length;

  V getOrCompute(K key, V Function() compute) {
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }
    final value = compute();
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return value;
  }

  void clear() => _entries.clear();
}
