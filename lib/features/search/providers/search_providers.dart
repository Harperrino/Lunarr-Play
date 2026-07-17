import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global search query — filters content on the active tab (not sidebar tabs).
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

/// Keeps typing immediate while coalescing catalogue-wide filtering work.
final catalogueSearchDebounceDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 140),
);

class DebouncedSearchQueryNotifier extends AutoDisposeNotifier<String> {
  Timer? _timer;

  @override
  String build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen<String>(globalSearchQueryProvider, (_, next) {
      _timer?.cancel();
      if (next.isEmpty) {
        state = '';
        return;
      }

      _timer = Timer(ref.read(catalogueSearchDebounceDurationProvider), () {
        state = next;
      });
    });
    return ref.read(globalSearchQueryProvider);
  }
}

final debouncedGlobalSearchQueryProvider =
    AutoDisposeNotifierProvider<DebouncedSearchQueryNotifier, String>(
      DebouncedSearchQueryNotifier.new,
    );
