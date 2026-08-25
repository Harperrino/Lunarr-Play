import 'package:material_ui/material_ui.dart';
import 'package:m3uxtream_player/core/models/discovery_preferences.dart';
import 'package:m3uxtream_player/l10n/l10n.dart';
import 'package:m3uxtream_player/shared/widgets/app_surface.dart';
import 'package:m3uxtream_player/shared/widgets/m3_dropdown_field.dart';

class DiscoveryToolbar extends StatelessWidget {
  const DiscoveryToolbar({
    super.key,
    required this.controller,
    required this.title,
    required this.source,
    required this.tmdbConfigured,
    required this.seerrConfigured,
    required this.canGoBack,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onBack,
    required this.onHome,
    required this.onRefresh,
    required this.onSourceChanged,
    required this.onOpenSettings,
  });

  final TextEditingController controller;
  final String title;
  final DiscoverySource source;
  final bool tmdbConfigured;
  final bool seerrConfigured;
  final bool canGoBack;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onRefresh;
  final ValueChanged<DiscoverySource> onSourceChanged;
  final VoidCallback onOpenSettings;

  bool get _sourceConfigured => switch (source) {
    DiscoverySource.tmdb => tmdbConfigured,
    DiscoverySource.seerr => seerrConfigured,
  };

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      level: AppSurfaceLevel.high,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 620 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final navigation = _navigation(context);
          final search = SearchBar(
            key: const ValueKey('discovery-search-field'),
            controller: controller,
            constraints: const BoxConstraints(
              minHeight: 48,
              maxHeight: 48,
              maxWidth: 420,
            ),
            hintText: context.l10n.discoverySearchHint,
            leading: const Icon(Icons.search_rounded),
            trailing: <Widget>[
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: context.l10n.discoverySearchClearTooltip,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          );
          final actions = <Widget>[
            _sourceControl(context),
            IconButton(
              tooltip: context.l10n.discoveryRefreshTooltip,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ];
          if (compact) {
            final searchWidth = constraints.maxWidth > 420
                ? 420.0
                : constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: navigation),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(width: searchWidth, child: search),
              ],
            );
          }
          return Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: navigation,
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.loose,
                child: SizedBox(width: 420, child: search),
              ),
              const SizedBox(width: 8),
              ...actions,
            ],
          );
        },
      ),
    );
  }

  Widget _navigation(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: context.l10n.discoveryBackTooltip,
        onPressed: canGoBack ? onBack : null,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      IconButton(
        tooltip: context.l10n.discoveryHomeTooltip,
        onPressed: onHome,
        icon: const Icon(Icons.home_rounded),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ],
  );

  Widget _sourceControl(BuildContext context) {
    String label(DiscoverySource value) => value == DiscoverySource.tmdb
        ? context.l10n.discoverySourceTmdb
        : context.l10n.discoverySourceSeerr;

    if (tmdbConfigured && seerrConfigured) {
      return M3DropdownField<DiscoverySource>(
        key: const ValueKey('discovery-source-dropdown'),
        value: source,
        width: 124,
        compact: true,
        entries: DiscoverySource.values
            .map(
              (value) => DropdownMenuEntry<DiscoverySource>(
                value: value,
                label: label(value),
                leadingIcon: Icon(
                  value == DiscoverySource.tmdb
                      ? Icons.public_rounded
                      : Icons.dns_rounded,
                ),
              ),
            )
            .toList(growable: false),
        onSelected: (value) {
          if (value != null && value != source) onSourceChanged(value);
        },
      );
    }
    if (_sourceConfigured) {
      return Chip(
        avatar: Icon(
          source == DiscoverySource.tmdb
              ? Icons.public_rounded
              : Icons.dns_rounded,
          size: 18,
        ),
        label: Text(label(source)),
      );
    }
    final alternative = tmdbConfigured
        ? DiscoverySource.tmdb
        : seerrConfigured
        ? DiscoverySource.seerr
        : null;
    if (alternative != null) {
      return FilledButton.tonalIcon(
        onPressed: () => onSourceChanged(alternative),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: Text(context.l10n.discoverySwitchSource(label(alternative))),
      );
    }
    return IconButton(
      tooltip: context.l10n.discoveryOpenSettings,
      onPressed: onOpenSettings,
      icon: const Icon(Icons.settings_rounded),
    );
  }
}
