import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_navigation_provider.dart';
import 'package:m3uxtream_player/features/discovery/providers/discovery_providers.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_toolbar.dart';
import 'package:m3uxtream_player/features/discovery/widgets/discovery_ui_text.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';

/// Feature-local adapter that supplies Discovery state to the shared top bar.
class DiscoveryTopBarControls extends ConsumerStatefulWidget {
  static const double preferredWidth = 900;

  const DiscoveryTopBarControls({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<DiscoveryTopBarControls> createState() =>
      _DiscoveryTopBarControlsState();
}

class _DiscoveryTopBarControlsState
    extends ConsumerState<DiscoveryTopBarControls> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(discoverySearchProvider);
    final query = search.valueOrNull?.query ?? '';
    _synchronizeSearchController(query);

    final navigation = ref.watch(discoveryNavigationProvider);
    final preferences =
        ref.watch(discoveryPreferencesProvider).valueOrNull ??
        const DiscoveryPreferences();
    final secrets =
        ref.watch(discoverySecretsProvider).valueOrNull ??
        const DiscoverySecrets();

    return DiscoveryToolbar(
      controller: _searchController,
      title: _title(context, navigation, query),
      source: preferences.source,
      tmdbConfigured: secrets.hasTmdbToken,
      seerrConfigured:
          secrets.hasSeerrApiKey && preferences.seerrEndpoint.trim().isNotEmpty,
      canGoBack: navigation.canGoBack || query.trim().isNotEmpty,
      onChanged: (value) =>
          ref.read(discoverySearchProvider.notifier).setQuery(value),
      onSubmitted: (value) =>
          ref.read(discoverySearchProvider.notifier).search(value),
      onClear: _clearSearch,
      onBack: _back,
      onHome: _home,
      onRefresh: _refresh,
      onSourceChanged: _switchSource,
      onOpenSettings: widget.onOpenSettings,
    );
  }

  String _title(
    BuildContext context,
    DiscoveryNavigationState navigation,
    String query,
  ) {
    if (navigation.current.type == DiscoveryDestinationType.details) {
      return navigation.current.item!.title;
    }
    if (query.trim().isNotEmpty) return context.l10n.discoverySearchTitle;
    if (navigation.current.type == DiscoveryDestinationType.category) {
      return discoveryShelfTitle(context.l10n, navigation.current.category!);
    }
    return context.l10n.shellTabHomeTitle;
  }

  void _synchronizeSearchController(String query) {
    if (_searchController.text == query) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _searchController.text == query) return;
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
      setState(() {});
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(discoverySearchProvider.notifier).clear();
  }

  void _back() {
    final navigation = ref.read(discoveryNavigationProvider);
    if (navigation.current.type == DiscoveryDestinationType.details) {
      ref.read(discoveryNavigationProvider.notifier).back();
      return;
    }
    final query = ref.read(discoverySearchProvider).valueOrNull?.query ?? '';
    if (query.trim().isNotEmpty) {
      _clearSearch();
      return;
    }
    ref.read(discoveryNavigationProvider.notifier).back();
  }

  void _home() {
    _clearSearch();
    ref.read(discoveryNavigationProvider.notifier).home();
  }

  void _refresh() {
    final search = ref.read(discoverySearchProvider).valueOrNull;
    if (search?.query.trim().isNotEmpty ?? false) {
      ref.read(discoverySearchProvider.notifier).search(search!.query);
      return;
    }
    final destination = ref.read(discoveryNavigationProvider).current;
    if (destination.type == DiscoveryDestinationType.category) {
      ref
          .read(discoveryCategoryProvider(destination.category!).notifier)
          .refresh();
      return;
    }
    ref.read(discoveryHomeProvider.notifier).refresh();
  }

  Future<void> _switchSource(DiscoverySource source) async {
    await ref.read(discoveryPreferencesProvider.notifier).setSource(source);
    if (!mounted) return;
    _home();
    ref.invalidate(discoveryHomeProvider);
    ref.invalidate(discoveryRequestProvider);
  }
}
