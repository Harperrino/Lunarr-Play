import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m3uxtream_player/features/search/providers/search_providers.dart';

void main() {
  testWidgets('catalogue search coalesces rapid input and clears immediately', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        catalogueSearchDebounceDurationProvider.overrideWith(
          (ref) => const Duration(milliseconds: 140),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      debouncedGlobalSearchQueryProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await tester.pump();
    expect(container.read(debouncedGlobalSearchQueryProvider), '');

    container.read(globalSearchQueryProvider.notifier).state = 'm';
    await tester.pump(const Duration(milliseconds: 50));
    container.read(globalSearchQueryProvider.notifier).state = 'mo';
    await tester.pump(const Duration(milliseconds: 50));
    container.read(globalSearchQueryProvider.notifier).state = 'movie';
    await tester.pump(const Duration(milliseconds: 139));

    expect(container.read(debouncedGlobalSearchQueryProvider), '');

    await tester.pump(const Duration(milliseconds: 1));
    expect(container.read(debouncedGlobalSearchQueryProvider), 'movie');

    container.read(globalSearchQueryProvider.notifier).state = '';
    await tester.pump();
    expect(container.read(debouncedGlobalSearchQueryProvider), '');
  });
}
