import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3uxtream_player/core/providers/infrastructure_providers.dart';
import 'package:m3uxtream_player/shared/navigation/shell_tabs.dart';

/// Persisted user choices for optional shell destinations.
final hiddenShellTabKindsProvider =
    AsyncNotifierProvider<HiddenShellTabKindsNotifier, Set<ShellTabKind>>(
      HiddenShellTabKindsNotifier.new,
    );

class HiddenShellTabKindsNotifier extends AsyncNotifier<Set<ShellTabKind>> {
  @override
  Future<Set<ShellTabKind>> build() async {
    final saved = await ref
        .read(appStateRepositoryProvider)
        .getHiddenShellTabs();
    return saved
        .map(_fromStorage)
        .whereType<ShellTabKind>()
        .where((kind) => kind != ShellTabKind.settings)
        .toSet();
  }

  Future<void> setVisible(ShellTabKind kind, bool visible) async {
    if (kind == ShellTabKind.settings) return;
    final next = {...(state.valueOrNull ?? const <ShellTabKind>{})};
    visible ? next.remove(kind) : next.add(kind);
    await ref
        .read(appStateRepositoryProvider)
        .setHiddenShellTabs(next.map((item) => item.name).toSet());
    state = AsyncData(next);
  }

  Future<void> reset() async {
    await ref.read(appStateRepositoryProvider).setHiddenShellTabs({});
    state = const AsyncData({});
  }

  ShellTabKind? _fromStorage(String value) {
    for (final kind in ShellTabKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }
}
