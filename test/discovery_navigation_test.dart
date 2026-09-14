import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_navigation_provider.dart';

void main() {
  test('back and home restore deterministic discovery destinations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(discoveryNavigationProvider.notifier);

    notifier.rememberHomeOffset(240);
    notifier.openCategory(DiscoveryShelfKind.popularMovies);
    notifier.rememberCategoryOffset(DiscoveryShelfKind.popularMovies, 480);
    notifier.openDetails(
      const DiscoveryMediaItem(
        id: 1,
        mediaType: DiscoveryMediaType.movie,
        title: 'Movie',
      ),
    );

    expect(
      container.read(discoveryNavigationProvider).current.type,
      DiscoveryDestinationType.details,
    );
    notifier.back();
    expect(
      container.read(discoveryNavigationProvider).current.category,
      DiscoveryShelfKind.popularMovies,
    );
    expect(
      container
          .read(discoveryNavigationProvider)
          .categoryScrollOffsets[DiscoveryShelfKind.popularMovies],
      480,
    );
    notifier.home();
    final home = container.read(discoveryNavigationProvider);
    expect(home.current.type, DiscoveryDestinationType.home);
    expect(home.homeScrollOffset, 0);
    expect(home.categoryScrollOffsets, isEmpty);
  });

  test('opening another title replaces the active detail destination', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(discoveryNavigationProvider.notifier);

    notifier.openDetails(
      const DiscoveryMediaItem(
        id: 1,
        mediaType: DiscoveryMediaType.movie,
        title: 'First',
      ),
    );
    notifier.openDetails(
      const DiscoveryMediaItem(
        id: 2,
        mediaType: DiscoveryMediaType.movie,
        title: 'Second',
      ),
    );

    final details = container.read(discoveryNavigationProvider);
    expect(details.stack, hasLength(2));
    expect(details.current.item?.id, 2);

    notifier.back();
    expect(
      container.read(discoveryNavigationProvider).current.type,
      DiscoveryDestinationType.home,
    );
  });

  test('replaced details return once to their category', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(discoveryNavigationProvider.notifier);

    notifier.openCategory(DiscoveryShelfKind.topRated);
    notifier.openDetails(
      const DiscoveryMediaItem(
        id: 1,
        mediaType: DiscoveryMediaType.tv,
        title: 'First',
      ),
    );
    notifier.openDetails(
      const DiscoveryMediaItem(
        id: 2,
        mediaType: DiscoveryMediaType.tv,
        title: 'Second',
      ),
    );

    expect(container.read(discoveryNavigationProvider).stack, hasLength(3));
    notifier.back();
    expect(
      container.read(discoveryNavigationProvider).current.category,
      DiscoveryShelfKind.topRated,
    );
  });
}
