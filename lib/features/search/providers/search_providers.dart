import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global search query — filters content on the active tab (not sidebar tabs).
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

/// Explicit lifetime and keyboard-selection state for the search overlay.
///
/// The selected filter intentionally lives in [searchOverlayFilterProvider]
/// so there is one source of truth for that part of the session. This state
/// owns only the lifecycle and highlighted result.
class SearchOverlaySessionState {
  const SearchOverlaySessionState({
    this.isOpen = false,
    this.highlightedIndex = 0,
  });

  final bool isOpen;
  final int highlightedIndex;

  SearchOverlaySessionState copyWith({bool? isOpen, int? highlightedIndex}) {
    return SearchOverlaySessionState(
      isOpen: isOpen ?? this.isOpen,
      highlightedIndex: highlightedIndex ?? this.highlightedIndex,
    );
  }
}

final searchOverlaySessionProvider = StateProvider<SearchOverlaySessionState>(
  (ref) => const SearchOverlaySessionState(),
);

/// Keeps typing immediate while coalescing catalogue-wide filtering work.
final catalogueSearchDebounceDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 80),
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
