import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/app/providers/tab_transition_probe_provider.dart';

/// Profile-only request counter for the tab-transition probe.
///
/// Counting Riverpod transitions into [AsyncLoading] keeps instrumentation at
/// app composition and avoids importing profiling concerns into leaf clients.
class TabTransitionProviderObserver extends ProviderObserver {
  const TabTransitionProviderObserver();

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (value is AsyncLoading<Object?>) _record(container);
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (newValue is AsyncLoading<Object?> &&
        previousValue is! AsyncLoading<Object?>) {
      _record(container);
    }
  }

  void _record(ProviderContainer container) {
    container.read(tabTransitionProbeProvider).recordRequest();
  }
}
