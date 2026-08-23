import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/jellyfin/auth/jellyfin_connection.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_item.dart';
import 'package:m3uxtream_player/features/jellyfin/models/jellyfin_library.dart';
import 'package:m3uxtream_player/features/jellyfin/providers/jellyfin_connection_providers.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_image_service.dart';
import 'package:m3uxtream_player/features/jellyfin/services/jellyfin_library_service.dart';

/// Injectable image URL builder.
final jellyfinImageServiceProvider = Provider<JellyfinImageService>(
  (ref) => const JellyfinImageService(),
);

/// Library orchestration with the authenticated API client.
final jellyfinLibraryServiceProvider = Provider<JellyfinLibraryService>((ref) {
  return JellyfinLibraryService(
    apiClient: ref.watch(jellyfinApiClientProvider),
  );
});

JellyfinConnection? _currentConnection(Ref ref) {
  final session = ref.watch(jellyfinSessionControllerProvider);
  return session is JellyfinAuthenticated ? session.connection : null;
}

/// Home screen aggregate (Continue Watching, Next Up, Latest, Libraries).
class JellyfinHomeDataNotifier extends AsyncNotifier<JellyfinHomeData> {
  @override
  Future<JellyfinHomeData> build() async {
    final connection = _currentConnection(ref);
    if (connection == null) {
      throw StateError('Jellyfin session is not authenticated.');
    }
    return ref.read(jellyfinLibraryServiceProvider).fetchHomeData(connection);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final jellyfinHomeDataProvider =
    AsyncNotifierProvider<JellyfinHomeDataNotifier, JellyfinHomeData>(
      JellyfinHomeDataNotifier.new,
    );

/// Items of one library folder.
class JellyfinLibraryItemsNotifier
    extends FamilyAsyncNotifier<List<JellyfinItem>, String> {
  @override
  Future<List<JellyfinItem>> build(String libraryId) async {
    final connection = _currentConnection(ref);
    if (connection == null) {
      throw StateError('Jellyfin session is not authenticated.');
    }
    final library = JellyfinLibrary(id: libraryId, name: libraryId);
    return ref
        .read(jellyfinLibraryServiceProvider)
        .fetchLibraryItems(connection, library);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final jellyfinLibraryItemsProvider =
    AsyncNotifierProvider.family<
      JellyfinLibraryItemsNotifier,
      List<JellyfinItem>,
      String
    >(JellyfinLibraryItemsNotifier.new);

/// Full detail of a single item.
class JellyfinItemDetailNotifier
    extends FamilyAsyncNotifier<JellyfinItem, String> {
  @override
  Future<JellyfinItem> build(String itemId) async {
    final connection = _currentConnection(ref);
    if (connection == null) {
      throw StateError('Jellyfin session is not authenticated.');
    }
    return ref
        .read(jellyfinLibraryServiceProvider)
        .fetchItemDetail(connection, itemId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final jellyfinItemDetailProvider =
    AsyncNotifierProvider.family<
      JellyfinItemDetailNotifier,
      JellyfinItem,
      String
    >(JellyfinItemDetailNotifier.new);

/// Episodes of a series.
class JellyfinSeriesEpisodesNotifier
    extends FamilyAsyncNotifier<List<JellyfinItem>, String> {
  @override
  Future<List<JellyfinItem>> build(String seriesId) async {
    final connection = _currentConnection(ref);
    if (connection == null) {
      throw StateError('Jellyfin session is not authenticated.');
    }
    return ref
        .read(jellyfinLibraryServiceProvider)
        .fetchSeriesEpisodes(connection, seriesId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final jellyfinSeriesEpisodesProvider =
    AsyncNotifierProvider.family<
      JellyfinSeriesEpisodesNotifier,
      List<JellyfinItem>,
      String
    >(JellyfinSeriesEpisodesNotifier.new);

/// Internal Jellyfin navigation stack. Home is the root; libraries and
/// details push onto it. Never touches global Lunarr navigation.
sealed class JellyfinRoute {
  const JellyfinRoute();
}

class JellyfinHomeRoute extends JellyfinRoute {
  const JellyfinHomeRoute();
}

class JellyfinLibraryRoute extends JellyfinRoute {
  const JellyfinLibraryRoute({required this.library});

  final JellyfinLibrary library;
}

class JellyfinDetailsRoute extends JellyfinRoute {
  const JellyfinDetailsRoute({required this.item});

  final JellyfinItem item;
}

class JellyfinPlayerRoute extends JellyfinRoute {
  const JellyfinPlayerRoute({required this.item});

  final JellyfinItem item;
}

final jellyfinViewStackProvider = StateProvider<List<JellyfinRoute>>(
  (ref) => const [JellyfinHomeRoute()],
);

/// Select the Jellyfin overview and discard any deeper browse path.
void jellyfinSelectOverview(WidgetRef ref) {
  ref.read(jellyfinViewStackProvider.notifier).state = const [
    JellyfinHomeRoute(),
  ];
}

/// Select a library from feature-local navigation and reset its browse path.
void jellyfinSelectLibrary(WidgetRef ref, JellyfinLibrary library) {
  ref.read(jellyfinViewStackProvider.notifier).state = [
    const JellyfinHomeRoute(),
    JellyfinLibraryRoute(library: library),
  ];
}

/// Returns the library context of the current detail/player path, if any.
JellyfinLibrary? jellyfinSelectedLibrary(List<JellyfinRoute> stack) {
  for (final route in stack.reversed) {
    if (route case JellyfinLibraryRoute(library: final library)) {
      return library;
    }
  }
  return null;
}

void jellyfinOpenLibrary(WidgetRef ref, JellyfinLibrary library) {
  final stack = ref.read(jellyfinViewStackProvider);
  ref.read(jellyfinViewStackProvider.notifier).state = [
    ...stack,
    JellyfinLibraryRoute(library: library),
  ];
}

void jellyfinOpenDetails(WidgetRef ref, JellyfinItem item) {
  final stack = ref.read(jellyfinViewStackProvider);
  ref.read(jellyfinViewStackProvider.notifier).state = [
    ...stack,
    JellyfinDetailsRoute(item: item),
  ];
}

void jellyfinOpenPlayer(WidgetRef ref, JellyfinItem item) {
  final stack = ref.read(jellyfinViewStackProvider);
  ref.read(jellyfinViewStackProvider.notifier).state = [
    ...stack,
    JellyfinPlayerRoute(item: item),
  ];
}

void jellyfinGoBack(WidgetRef ref) {
  final stack = ref.read(jellyfinViewStackProvider);
  if (stack.length <= 1) return;
  ref.read(jellyfinViewStackProvider.notifier).state = stack.sublist(
    0,
    stack.length - 1,
  );
}
