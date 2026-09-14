import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/features/discovery/models/discovery_models.dart';

enum DiscoveryDestinationType { home, category, details }

class DiscoveryDestination {
  const DiscoveryDestination._({required this.type, this.category, this.item});

  const DiscoveryDestination.home()
    : this._(type: DiscoveryDestinationType.home);

  const DiscoveryDestination.category(DiscoveryShelfKind category)
    : this._(type: DiscoveryDestinationType.category, category: category);

  const DiscoveryDestination.details(DiscoveryMediaItem item)
    : this._(type: DiscoveryDestinationType.details, item: item);

  final DiscoveryDestinationType type;
  final DiscoveryShelfKind? category;
  final DiscoveryMediaItem? item;
}

class DiscoveryNavigationState {
  const DiscoveryNavigationState({
    this.stack = const <DiscoveryDestination>[DiscoveryDestination.home()],
    this.homeScrollOffset = 0,
    this.categoryScrollOffsets = const <DiscoveryShelfKind, double>{},
  });

  final List<DiscoveryDestination> stack;
  final double homeScrollOffset;
  final Map<DiscoveryShelfKind, double> categoryScrollOffsets;

  DiscoveryDestination get current => stack.last;
  bool get canGoBack => stack.length > 1;

  DiscoveryNavigationState copyWith({
    List<DiscoveryDestination>? stack,
    double? homeScrollOffset,
    Map<DiscoveryShelfKind, double>? categoryScrollOffsets,
  }) => DiscoveryNavigationState(
    stack: stack ?? this.stack,
    homeScrollOffset: homeScrollOffset ?? this.homeScrollOffset,
    categoryScrollOffsets: categoryScrollOffsets ?? this.categoryScrollOffsets,
  );
}

final discoveryNavigationProvider =
    NotifierProvider.autoDispose<
      DiscoveryNavigationNotifier,
      DiscoveryNavigationState
    >(DiscoveryNavigationNotifier.new);

class DiscoveryNavigationNotifier
    extends AutoDisposeNotifier<DiscoveryNavigationState> {
  @override
  DiscoveryNavigationState build() => const DiscoveryNavigationState();

  void openCategory(DiscoveryShelfKind kind) {
    state = state.copyWith(
      stack: <DiscoveryDestination>[
        ...state.stack,
        DiscoveryDestination.category(kind),
      ],
    );
  }

  void openDetails(DiscoveryMediaItem item) {
    final destination = DiscoveryDestination.details(item);
    final stack = state.current.type == DiscoveryDestinationType.details
        ? <DiscoveryDestination>[
            ...state.stack.take(state.stack.length - 1),
            destination,
          ]
        : <DiscoveryDestination>[...state.stack, destination];
    state = state.copyWith(stack: stack);
  }

  void back() {
    if (!state.canGoBack) return;
    state = state.copyWith(
      stack: state.stack.sublist(0, state.stack.length - 1),
    );
  }

  void home() => state = const DiscoveryNavigationState();

  void rememberHomeOffset(double offset) {
    if (!offset.isFinite || offset < 0) return;
    state = state.copyWith(homeScrollOffset: offset);
  }

  void rememberCategoryOffset(DiscoveryShelfKind kind, double offset) {
    if (!offset.isFinite || offset < 0) return;
    state = state.copyWith(
      categoryScrollOffsets: <DiscoveryShelfKind, double>{
        ...state.categoryScrollOffsets,
        kind: offset,
      },
    );
  }

  void resetSession() => state = const DiscoveryNavigationState();
}
