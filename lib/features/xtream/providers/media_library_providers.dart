import 'package:flutter_riverpod/flutter_riverpod.dart';

const mediaLibraryMoviesTabIndex = 0;
const mediaLibrarySeriesTabIndex = 1;
const mediaLibraryWatchLaterTabIndex = 2;

/// Session-local subtab state; it is deliberately not persisted.
final mediaLibraryTabProvider = StateProvider<int>((ref) {
  return mediaLibraryMoviesTabIndex;
});
